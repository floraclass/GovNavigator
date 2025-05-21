;; GovNavigator - A decentralized government services directory
;; Author: Your Name
;; Version: 1.0.0

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SERVICE_NOT_FOUND (err u101))
(define-constant ERR_INVALID_RATING (err u102))
(define-constant ERR_ALREADY_RATED (err u103))

;; Data structures
(define-map services
  { service-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    requirements: (string-utf8 1000),
    steps: (string-utf8 1000),
    contact: (string-utf8 200),
    category: (string-utf8 50),
    avg-rating: uint,
    rating-count: uint,
    created-at: uint,
    updated-at: uint
  }
)

(define-map service-ratings
  { service-id: uint, user: principal }
  { rating: uint }
)

(define-map service-categories
  { category-id: uint }
  { name: (string-utf8 50) }
)

(define-map admins
  { admin: principal }
  { active: bool }
)

;; Initialize contract owner as admin
(define-data-var contract-owner principal tx-sender)

;; Service counter for generating IDs
(define-data-var service-counter uint u0)
(define-data-var category-counter uint u0)

;; Admin functions

(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (ok (map-set admins { admin: new-admin } { active: true }))
  )
)

(define-public (remove-admin (admin-to-remove principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq admin-to-remove (var-get contract-owner))) ERR_UNAUTHORIZED)
    (ok (map-set admins { admin: admin-to-remove } { active: false }))
  )
)

;; Service management functions

(define-public (add-service 
    (name (string-utf8 100))
    (description (string-utf8 500))
    (requirements (string-utf8 1000))
    (steps (string-utf8 1000))
    (contact (string-utf8 200))
    (category (string-utf8 50))
  )
  (let
    (
      (service-id (+ (var-get service-counter) u1))
    )
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set service-counter service-id)
    (ok (map-set services
      { service-id: service-id }
      {
        name: name,
        description: description,
        requirements: requirements,
        steps: steps,
        contact: contact,
        category: category,
        avg-rating: u0,
        rating-count: u0,
        created-at: stacks-block-height,
        updated-at: stacks-block-height
      }
    ))
  )
)

(define-public (update-service
    (service-id uint)
    (name (string-utf8 100))
    (description (string-utf8 500))
    (requirements (string-utf8 1000))
    (steps (string-utf8 1000))
    (contact (string-utf8 200))
    (category (string-utf8 50))
  )
  (let
    (
      (service (unwrap! (map-get? services { service-id: service-id }) ERR_SERVICE_NOT_FOUND))
    )
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (ok (map-set services
      { service-id: service-id }
      {
        name: name,
        description: description,
        requirements: requirements,
        steps: steps,
        contact: contact,
        category: category,
        avg-rating: (get avg-rating service),
        rating-count: (get rating-count service),
        created-at: (get created-at service),
        updated-at: stacks-block-height
      }
    ))
  )
)

(define-public (add-category (name (string-utf8 50)))
  (let
    (
      (category-id (+ (var-get category-counter) u1))
    )
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set category-counter category-id)
    (ok (map-set service-categories
      { category-id: category-id }
      { name: name }
    ))
  )
)

;; User interaction functions

(define-public (rate-service (service-id uint) (rating uint))
  (let
    (
      (service (unwrap! (map-get? services { service-id: service-id }) ERR_SERVICE_NOT_FOUND))
      (existing-rating (map-get? service-ratings { service-id: service-id, user: tx-sender }))
      (current-avg (get avg-rating service))
      (current-count (get rating-count service))
      (new-count (+ current-count u1))
      (new-avg (/ (+ (* current-avg current-count) rating) new-count))
    )
    ;; Validate rating is between 1 and 5
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    ;; Ensure user hasn't already rated this service
    (asserts! (is-none existing-rating) ERR_ALREADY_RATED)
    
    ;; Store the user's rating
    (map-set service-ratings 
      { service-id: service-id, user: tx-sender } 
      { rating: rating }
    )
    
    ;; Update the service's average rating
    (ok (map-set services
      { service-id: service-id }
      (merge service { 
        avg-rating: new-avg,
        rating-count: new-count
      })
    ))
  )
)

;; Read-only functions

(define-read-only (get-service (service-id uint))
  (map-get? services { service-id: service-id })
)

(define-read-only (get-service-count)
  (var-get service-counter)
)

(define-read-only (get-category (category-id uint))
  (map-get? service-categories { category-id: category-id })
)

(define-read-only (get-user-rating (service-id uint) (user principal))
  (map-get? service-ratings { service-id: service-id, user: user })
)

(define-read-only (is-admin (user principal))
  (or
    (is-eq user (var-get contract-owner))
    (default-to false (get active (map-get? admins { admin: user })))
  )
)
