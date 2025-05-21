
```clarity file="tests/gov-navigator_test.clar" type="code"
;; GovNavigator Contract Tests

(use-trait mock-trait .mock-trait.mock-trait)

;; Initialize test wallets
(define-constant wallet_1 tx-sender)
(define-constant wallet_2 'ST1J4G6RR643BCG8G8SR6M2D9Z9KXT2NJDRK3FBTK)
(define-constant wallet_3 'ST20ATRN26N9P05V2F1RHFRV24X8C8M3W54E427B2)

;; Test adding a service
(define-public (test-add-service)
  (begin
    ;; Only admin (contract owner) should be able to add a service
    (try! (contract-call? .gov-navigator add-service 
      "Passport Application" 
      "Apply for a new passport or renew an existing one" 
      "1. Valid ID\n2. Birth certificate\n3. Passport photos\n4. Application fee" 
      "1. Complete online form\n2. Schedule appointment\n3. Submit documents\n4. Pay fee\n5. Collect passport" 
      "Immigration Office: +123-456-7890, passport@gov.example" 
      "Identity Documents"
    ))
    
    ;; Verify service was added correctly
    (let ((service (unwrap! (contract-call? .gov-navigator get-service u1) (err "Service not found"))))
      (asserts! (is-eq (get name service) "Passport Application") (err "Service name mismatch"))
      (asserts! (is-eq (get avg-rating service) u0) (err "Initial rating should be 0"))
      (asserts! (is-eq (get rating-count service) u0) (err "Initial rating count should be 0"))
    )
    
    ;; Non-admin should not be able to add a service
    (as-contract tx-sender
      (asserts! 
        (is-err (contract-call? .gov-navigator add-service 
          "Test Service" "Description" "Requirements" "Steps" "Contact" "Category"
        ))
        (err "Non-admin should not be able to add service")
      )
    )
    
    (ok true)
  )
)

;; Test updating a service
(define-public (test-update-service)
  (begin
    ;; First add a service
    (try! (contract-call? .gov-navigator add-service 
      "Business Registration" 
      "Register a new business" 
      "Requirements" "Steps" "Contact" "Business"
    ))
    
    ;; Update the service
    (try! (contract-call? .gov-navigator update-service 
      u2
      "Business Registration" 
      "Register a new business entity" 
      "Updated requirements" 
      "Updated steps" 
      "Updated contact" 
      "Business"
    ))
    
    ;; Verify service was updated correctly
    (let ((service (unwrap! (contract-call? .gov-navigator get-service u2) (err "Service not found"))))
      (asserts! (is-eq (get description service) "Register a new business entity") (err "Service description not updated"))
      (asserts! (is-eq (get requirements service) "Updated requirements") (err "Service requirements not updated"))
    )
    
    (ok true)
  )
)

;; Test rating a service
(define-public (test-rate-service)
  (begin
    ;; First add a service
    (try! (contract-call? .gov-navigator add-service 
      "NIN Registration" 
      "Register for National ID Number" 
      "Requirements" "Steps" "Contact" "Identity Documents"
    ))
    
    ;; Rate the service as wallet_2
    (as wallet_2
      (try! (contract-call? .gov-navigator rate-service u3 u4))
    )
    
    ;; Rate the service as wallet_3
    (as wallet_3
      (try! (contract-call? .gov-navigator rate-service u3 u5))
    )
    
    ;; Verify ratings were recorded correctly
    (let ((service (unwrap! (contract-call? .gov-navigator get-service u3) (err "Service not found"))))
      (asserts! (is-eq (get avg-rating service) u4) (err "Average rating incorrect"))
      (asserts! (is-eq (get rating-count service) u2) (err "Rating count incorrect"))
    )
    
    ;; Verify wallet_2 can't rate again
    (as wallet_2
      (asserts! 
        (is-err (contract-call? .gov-navigator rate-service u3 u3))
        (err "Should not be able to rate twice")
      )
    )
    
    ;; Verify invalid ratings are rejected
    (as wallet_1
      (asserts! 
        (is-err (contract-call? .gov-navigator rate-service u3 u6))
        (err "Rating above 5 should be rejected")
      )
    )
    
    (ok true)
  )
)

;; Test admin management
(define-public (test-admin-management)
  (begin
    ;; Add wallet_2 as admin
    (try! (contract-call? .gov-navigator add-admin wallet_2))
    
    ;; Verify wallet_2 can now add a service
    (as wallet_2
      (try! (contract-call? .gov-navigator add-service 
        "Tax Filing" 
        "File annual taxes" 
        "Requirements" "Steps" "Contact" "Taxation"
      ))
    )
    
    ;; Remove wallet_2 as admin
    (try! (contract-call? .gov-navigator remove-admin wallet_2))
    
    ;; Verify wallet_2 can no longer add a service
    (as wallet_2
      (asserts! 
        (is-err (contract-call? .gov-navigator add-service 
          "Test Service" "Description" "Requirements" "Steps" "Contact" "Category"
        ))
        (err "Removed admin should not be able to add service")
      )
    )
    
    (ok true)
  )
)

;; Run all tests
(define-public (run-tests)
  (begin
    (try! (test-add-service))
    (try! (test-update-service))
    (try! (test-rate-service))
    (try! (test-admin-management))
    (ok true)
  )
)