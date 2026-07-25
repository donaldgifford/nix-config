;; extends

; `use expiration` feature flags — nodes exist only in our patched grammar
; (donaldgifford/tree-sitter-authzed feat/use-statement)
(use_literal) @keyword.import

(use_statement
  feature: (identifier) @constant.builtin)
