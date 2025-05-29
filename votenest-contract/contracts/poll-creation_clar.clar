;; title: poll-creation.clar
;; version: 1.0
;; summary: A contract for creating and managing polls
;; description: This contract allows users to create polls with customizable parameters, including title, description, options, voting rules, start and end times, and eligibility criteria.

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-poll (err u101))
(define-constant err-poll-exists (err u102))

;; Define data variables
(define-data-var poll-count uint u0)

;; Define voting rules
(define-constant MAJORITY-VOTE u1)
(define-constant RANKED-CHOICE u2)

;; Define poll structure
(define-map polls
  { poll-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    options: (list 10 (string-ascii 50)),
    voting-rule: uint,
    start-time: uint,
    end-time: uint,
    eligibility-criteria: (string-ascii 100),
    creator: principal
  }
)

;; Create a new poll
(define-public (create-poll 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (options (list 10 (string-ascii 50)))
    (voting-rule uint)
    (start-time uint)
    (end-time uint)
    (eligibility-criteria (string-ascii 100)))
  (let 
    ((poll-id (var-get poll-count)))
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (> (len options) u1) err-invalid-poll)
    (asserts! (or (is-eq voting-rule MAJORITY-VOTE) (is-eq voting-rule RANKED-CHOICE)) err-invalid-poll)
    (asserts! (< start-time end-time) err-invalid-poll)
    (asserts! (is-none (map-get? polls { poll-id: poll-id })) err-poll-exists)
    
    (map-set polls
      { poll-id: poll-id }
      {
        title: title,
        description: description,
        options: options,
        voting-rule: voting-rule,
        start-time: start-time,
        end-time: end-time,
        eligibility-criteria: eligibility-criteria,
        creator: tx-sender
      }
    )
    (var-set poll-count (+ poll-id u1))
    (ok poll-id)
  )
)

;; Get poll details
(define-read-only (get-poll (poll-id uint))
  (map-get? polls { poll-id: poll-id })
)

;; Get total number of polls
(define-read-only (get-poll-count)
  (var-get poll-count)
)

;; Check if a user is eligible to vote
(define-read-only (is-eligible-to-vote (poll-id uint) (user principal))
  (match (get-poll poll-id)
    poll (and 
      (>= stacks-block-height (get start-time poll))
      (<= stacks-block-height (get end-time poll))
      (check-eligibility (get eligibility-criteria poll) user))
    false
  )
)

(define-private (check-eligibility (criteria (string-ascii 100)) (user principal))
  (if (is-eq criteria "token-holders")
    (> (stx-get-balance user) u0)
    (if (is-eq criteria "verified-identities")
      (get-verified-status user)
      (if (is-eq criteria "all")
        true
        false
      )
    )
  )
)

;; Placeholder function for getting verified status
(define-read-only (get-verified-status (user principal))
  ;; In a real implementation, this would check against a verified users list or another contract
  false
)