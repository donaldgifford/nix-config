# aws — structured AWS CLI helpers.
#
# Imported flat from config.nu (`use aws.nu *`) with `aws-` prefixed names,
# so the external `aws` binary is never shadowed. Every command honours the
# usual AWS_PROFILE / AWS_REGION env (see `aws-ctx` for switching).

# ── private helpers ──────────────────────────────────────────────────────────

# Read a tag value off an EC2-style Tags list, or a fallback
def tag-value [tags: list, key: string, fallback: string = "-"] {
  let hits = ($tags | default [] | where Key == $key)
  if ($hits | is-empty) { $fallback } else { $hits.0.Value }
}

# Optional --profile/--region flags as a list for spreading into aws
def aws-flags [profile: string, region: string] {
  ([]
    | append (if $profile == "" { [] } else { ["--profile" $profile] })
    | append (if $region == "" { [] } else { ["--region" $region] }))
}

# Directory holding per-environment overlays (gitignored; see overlays/README.md)
def overlays-dir [] {
  $nu.home-dir | path join ".config" "nushell" "overlays"
}

# ── identity / context ───────────────────────────────────────────────────────

# Who am I? account, ARN, profile, region — in one record
export def aws-whoami [] {
  let id = (aws sts get-caller-identity | from json)
  {
    account: $id.Account
    arn: $id.Arn
    user_id: $id.UserId
    profile: ($env.AWS_PROFILE? | default "(default)")
    region: ($env.AWS_REGION? | default $env.AWS_DEFAULT_REGION? | default "(unset)")
  }
}

# Profiles configured in ~/.aws/config and ~/.aws/credentials
export def aws-profiles [] {
  aws configure list-profiles | lines | sort
}

# Switch AWS context: sets AWS_PROFILE (and optionally AWS_REGION) for this shell
export def --env aws-ctx [
  profile?: string                     # profile name; omit to show current
  --region (-r): string                # also set AWS_REGION
] {
  if $profile == null {
    return {
      profile: ($env.AWS_PROFILE? | default "(default)")
      region: ($env.AWS_REGION? | default "(unset)")
    }
  }
  $env.AWS_PROFILE = $profile
  if $region != null { $env.AWS_REGION = $region }
  print $"AWS_PROFILE=($profile)(if $region != null { $' AWS_REGION=($region)' } else { '' })"
}

# ── ec2 ──────────────────────────────────────────────────────────────────────

# EC2 instances as a table (Name tag, id, type, state, IPs, launch time)
export def aws-ec2 [
  --profile (-p): string = ""
  --region (-r): string = ""
  --running                            # only running instances
] {
  aws ec2 describe-instances ...(aws-flags $profile $region)
    | from json
    | get Reservations
    | get Instances
    | flatten
    | each {|i|
        {
          name: (tag-value ($i.Tags? | default []) "Name")
          id: $i.InstanceId
          type: $i.InstanceType
          state: $i.State.Name
          private_ip: ($i.PrivateIpAddress? | default "")
          public_ip: ($i.PublicIpAddress? | default "")
          az: $i.Placement.AvailabilityZone
          launched: ($i.LaunchTime | into datetime)
        }
      }
    | if $running { where state == "running" } else { $in }
    | sort-by name
}

# Instance counts grouped by type — quick fleet shape / cost sanity check
export def aws-ec2-by-type [
  --profile (-p): string = ""
  --region (-r): string = ""
] {
  aws-ec2 -p $profile -r $region --running
    | group-by type
    | transpose type instances
    | each {|g| { type: $g.type, count: ($g.instances | length) } }
    | sort-by count -r
}

# Security groups with their inbound rules flattened one-per-row
export def aws-sg-ingress [
  --profile (-p): string = ""
  --region (-r): string = ""
] {
  aws ec2 describe-security-groups ...(aws-flags $profile $region)
    | from json
    | get SecurityGroups
    | each {|sg|
        $sg.IpPermissions | each {|p|
          {
            group: $sg.GroupName
            id: $sg.GroupId
            proto: ($p.IpProtocol | if $in == "-1" { "all" } else { $in })
            from: ($p.FromPort? | default "*")
            to: ($p.ToPort? | default "*")
            cidrs: ($p.IpRanges | get CidrIp | str join ",")
          }
        }
      }
    | flatten
}

# ── eks ──────────────────────────────────────────────────────────────────────

# EKS clusters with version, status, endpoint
export def aws-eks-clusters [
  --profile (-p): string = ""
  --region (-r): string = ""
] {
  let flags = (aws-flags $profile $region)
  aws eks list-clusters ...$flags
    | from json
    | get clusters
    | par-each {|name|
        let c = (aws eks describe-cluster --name $name ...$flags | from json | get cluster)
        {
          name: $c.name
          version: $c.version
          status: $c.status
          platform: ($c.platformVersion? | default "")
          endpoint: $c.endpoint
          created: ($c.createdAt | into datetime)
        }
      }
    | sort-by name
}

# Node groups for one EKS cluster: instance types, scaling config, AMI
export def aws-eks-nodegroups [
  cluster: string
  --profile (-p): string = ""
  --region (-r): string = ""
] {
  let flags = (aws-flags $profile $region)
  aws eks list-nodegroups --cluster-name $cluster ...$flags
    | from json
    | get nodegroups
    | par-each {|ng|
        let n = (aws eks describe-nodegroup --cluster-name $cluster --nodegroup-name $ng ...$flags
                 | from json | get nodegroup)
        {
          name: $n.nodegroupName
          status: $n.status
          types: ($n.instanceTypes? | default [] | str join ",")
          min: $n.scalingConfig.minSize
          desired: $n.scalingConfig.desiredSize
          max: $n.scalingConfig.maxSize
          ami: ($n.amiType? | default "")
          release: ($n.releaseVersion? | default "")
        }
      }
}

# Write/refresh kubeconfig for an EKS cluster, then show the context
export def aws-eks-kubeconfig [
  cluster: string
  --profile (-p): string = ""
  --region (-r): string = ""
  --alias (-a): string                 # kubeconfig context alias
] {
  let flags = (aws-flags $profile $region)
  let alias_flags = (if $alias == null { [] } else { ["--alias" $alias] })
  aws eks update-kubeconfig --name $cluster ...$flags ...$alias_flags
  kubectl config current-context
}

# ── iam ──────────────────────────────────────────────────────────────────────

# IAM roles sorted by creation date
export def aws-iam-roles [
  --profile (-p): string = ""
  --prefix: string                     # only roles whose name starts with this
] {
  aws iam list-roles ...(aws-flags $profile "")
    | from json
    | get Roles
    | each {|r|
        {
          name: $r.RoleName
          created: ($r.CreateDate | into datetime)
          last_used: ($r.RoleLastUsed?.LastUsedDate? | default "never")
          path: $r.Path
        }
      }
    | if $prefix == null { $in } else { where name starts-with $prefix }
    | sort-by created -r
}

# IAM users and the age of each access key — audit rotation
export def aws-iam-keys [
  --profile (-p): string = ""
  --older-than (-o): int = 0           # only keys older than N days
] {
  let flags = (aws-flags $profile "")
  aws iam list-users ...$flags
    | from json
    | get Users
    | par-each {|u|
        aws iam list-access-keys --user-name $u.UserName ...$flags
          | from json
          | get AccessKeyMetadata
          | each {|k|
              let age = ((date now) - ($k.CreateDate | into datetime))
              {
                user: $u.UserName
                key_id: $k.AccessKeyId
                status: $k.Status
                age_days: ($age / 1day | math floor)
              }
            }
      }
    | flatten
    | where age_days >= $older_than
    | sort-by age_days -r
}

# ── s3 ───────────────────────────────────────────────────────────────────────

# Buckets with creation date and (optionally) region
export def aws-s3-buckets [
  --profile (-p): string = ""
  --with-region                        # extra API call per bucket
] {
  let flags = (aws-flags $profile "")
  aws s3api list-buckets ...$flags
    | from json
    | get Buckets
    | each {|b| { name: $b.Name, created: ($b.CreationDate | into datetime) } }
    | if $with_region {
        par-each {|b|
          let loc = (aws s3api get-bucket-location --bucket $b.name ...$flags
                     | from json | get LocationConstraint)
          $b | insert region ($loc | default "us-east-1")
        }
      } else { $in }
    | sort-by name
}

# Total size + object count for an S3 prefix (s3://bucket/prefix)
export def aws-s3-size [
  uri: string                          # s3://bucket or s3://bucket/prefix
  --profile (-p): string = ""
] {
  let flags = (aws-flags $profile "")
  let summary = (aws s3 ls $uri --recursive --summarize ...$flags | lines | last 2)
  {
    uri: $uri
    objects: ($summary.0 | parse "Total Objects: {n}" | get 0.n | into int)
    size: ($summary.1 | parse "   Total Size: {b}" | get 0.b | into int | into filesize)
  }
}

# ── overlays ─────────────────────────────────────────────────────────────────

# List environment overlays available in ~/.config/nushell/overlays
export def aws-overlays [] {
  let dir = (overlays-dir)
  if not ($dir | path exists) { return [] }
  ls $dir | where name ends-with ".nu" | get name | path basename | str replace ".nu" ""
}
