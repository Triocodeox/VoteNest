;; Admin Role Management Contract
;; Allows contract deployer to manage admins and control proposal permissions

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ADMIN_NOT_FOUND (err u101))
(define-constant ERR_ADMIN_ALREADY_EXISTS (err u102))
(define-constant ERR_CANNOT_REMOVE_OWNER (err u103))
(define-constant ERR_INVALID_PRINCIPAL (err u104))

;; Data Variables
(define-data-var contract-owner principal CONTRACT_OWNER)

;; Data Maps
(define-map admins principal bool)
(define-map proposals 
  uint 
  {
    id: uint,
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    status: (string-ascii 20),
    created-at: uint,
    votes-for: uint,
    votes-against: uint
  }
)

(define-map proposal-votes {proposal-id: uint, voter: principal} bool)
(define-data-var next-proposal-id uint u1)

;; Initialize contract owner as first admin
(map-set admins CONTRACT_OWNER true)

;; Read-only functions

;; Check if a principal is an admin
(define-read-only (is-admin (user principal))
  (default-to false (map-get? admins user))
)

;; Check if a principal is the contract owner
(define-read-only (is-contract-owner (user principal))
  (is-eq user (var-get contract-owner))
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; Check if user has voted on a proposal
(define-read-only (has-voted (proposal-id uint) (voter principal))
  (is-some (map-get? proposal-votes {proposal-id: proposal-id, voter: voter}))
)

;; Get next proposal ID
(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

;; Private functions

;; Check if caller is authorized (owner or admin)
(define-private (is-authorized (caller principal))
  (or (is-contract-owner caller) (is-admin caller))
)

;; Public functions

;; Add a new admin (only contract owner can do this)
(define-public (add-admin (new-admin principal))
  (begin
    ;; Check if caller is contract owner
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check if admin doesn't already exist
    (asserts! (not (is-admin new-admin)) ERR_ADMIN_ALREADY_EXISTS)
    
    ;; Add admin
    (map-set admins new-admin true)
    
    ;; Print event
    (print {
      event: "admin-added",
      admin: new-admin,
      added-by: tx-sender,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Remove an admin (only contract owner can do this)
(define-public (remove-admin (admin-to-remove principal))
  (begin
    ;; Check if caller is contract owner
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check if admin exists
    (asserts! (is-admin admin-to-remove) ERR_ADMIN_NOT_FOUND)
    
    ;; Cannot remove contract owner
    (asserts! (not (is-contract-owner admin-to-remove)) ERR_CANNOT_REMOVE_OWNER)
    
    ;; Remove admin
    (map-delete admins admin-to-remove)
    
    ;; Print event
    (print {
      event: "admin-removed",
      admin: admin-to-remove,
      removed-by: tx-sender,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Transfer contract ownership (only current owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Check if caller is current owner
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    
    ;; Update contract owner
    (var-set contract-owner new-owner)
    
    ;; Add new owner as admin
    (map-set admins new-owner true)
    
    ;; Print event
    (print {
      event: "ownership-transferred",
      old-owner: tx-sender,
      new-owner: new-owner,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Create a proposal (only admins can create proposals)
(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (proposal-id (var-get next-proposal-id))
    )
    ;; Check if caller is authorized (admin or owner)
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    ;; Create proposal
    (map-set proposals proposal-id {
      id: proposal-id,
      creator: tx-sender,
      title: title,
      description: description,
      status: "active",
      created-at: stacks-block-height,
      votes-for: u0,
      votes-against: u0
    })
    
    ;; Increment next proposal ID
    (var-set next-proposal-id (+ proposal-id u1))
    
    ;; Print event
    (print {
      event: "proposal-created",
      proposal-id: proposal-id,
      creator: tx-sender,
      title: title,
      block-height: stacks-block-height
    })
    
    (ok proposal-id)
  )
)

;; Vote on a proposal (only admins can vote)
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_INVALID_PRINCIPAL))
      (current-votes-for (get votes-for proposal))
      (current-votes-against (get votes-against proposal))
    )
    ;; Check if caller is authorized
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    ;; Check if user hasn't voted yet
    (asserts! (not (has-voted proposal-id tx-sender)) ERR_UNAUTHORIZED)
    
    ;; Record vote
    (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} vote)
    
    ;; Update proposal vote counts
    (if vote
      (map-set proposals proposal-id (merge proposal {votes-for: (+ current-votes-for u1)}))
      (map-set proposals proposal-id (merge proposal {votes-against: (+ current-votes-against u1)}))
    )
    
    ;; Print event
    (print {
      event: "vote-cast",
      proposal-id: proposal-id,
      voter: tx-sender,
      vote: vote,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Close a proposal (only admins can close proposals)
(define-public (close-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) ERR_INVALID_PRINCIPAL))
    )
    ;; Check if caller is authorized
    (asserts! (is-authorized tx-sender) ERR_UNAUTHORIZED)
    
    ;; Update proposal status
    (map-set proposals proposal-id (merge proposal {status: "closed"}))
    
    ;; Print event
    (print {
      event: "proposal-closed",
      proposal-id: proposal-id,
      closed-by: tx-sender,
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal),
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)

;; Emergency pause function (only contract owner)
(define-public (emergency-pause)
  (begin
    ;; Check if caller is contract owner
    (asserts! (is-contract-owner tx-sender) ERR_UNAUTHORIZED)
    
    ;; Print emergency event
    (print {
      event: "emergency-pause",
      paused-by: tx-sender,
      block-height: stacks-block-height
    })
    
    (ok true)
  )
)