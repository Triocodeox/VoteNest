;; Token-Weighted Voting Contract
;; This contract implements voting power based on token ownership with optional quadratic voting

;; Define SIP-010 fungible token trait
;; (use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Define SIP-009 non-fungible token trait
;; (use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Define data variables
(define-data-var token-type (string-ascii 10) "NONE") ;; "FT" or "NFT"
(define-data-var token-contract principal 'SP000000000000000000002Q6VF78.none)
(define-data-var voting-type (string-ascii 10) "STANDARD") ;; "STANDARD" or "QUADRATIC"
(define-data-var proposal-count uint u0)

;; Define maps
(define-map proposals
  { proposal-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 500),
    start-block: uint,
    end-block: uint,
    is-active: bool
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  {
    vote-choice: uint,
    vote-power: uint
  }
)

(define-map proposal-vote-totals
  { proposal-id: uint, vote-choice: uint }
  { total: uint }
)

;; Define constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-TOKEN-TYPE (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-VOTING-ENDED (err u103))
(define-constant ERR-VOTING-NOT-STARTED (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant ERR-NO-TOKEN-BALANCE (err u106))

;; Initialize contract with token information
(define-public (initialize-contract (token-contract-addr principal) (token-standard (string-ascii 10)) (voting-mechanism (string-ascii 10)))
  (begin
    ;; Only contract owner can initialize
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Validate token type
    (asserts! (or (is-eq token-standard "FT") (is-eq token-standard "NFT")) ERR-INVALID-TOKEN-TYPE)
    
    ;; Set token information
    (var-set token-type token-standard)
    (var-set token-contract token-contract-addr)
    
    ;; Set voting mechanism
    (var-set voting-type voting-mechanism)
    
    (ok true)))

;; Create a new proposal
(define-public (create-proposal (title (string-utf8 100)) (description (string-utf8 500)) (duration uint))
  (let
    ((proposal-id (var-get proposal-count))
     (start-block stacks-block-height)
     (end-block (+ stacks-block-height duration)))
    
    ;; Only contract owner can create proposals
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    ;; Store proposal details
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        start-block: start-block,
        end-block: end-block,
        is-active: true
      }
    )
    
    ;; Increment proposal count
    (var-set proposal-count (+ (var-get proposal-count) u1))
    
    (ok proposal-id)))

