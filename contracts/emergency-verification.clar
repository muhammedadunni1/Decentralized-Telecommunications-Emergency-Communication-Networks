;; Emergency Service Verification Contract
;; Validates and manages emergency communication services

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SERVICE_NOT_FOUND (err u101))
(define-constant ERR_SERVICE_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_SERVICE_TYPE (err u103))

;; Service types
(define-constant SERVICE_TYPE_FIRE u1)
(define-constant SERVICE_TYPE_POLICE u2)
(define-constant SERVICE_TYPE_MEDICAL u3)
(define-constant SERVICE_TYPE_RESCUE u4)

;; Data structures
(define-map emergency-services
  { service-id: uint }
  {
    service-name: (string-ascii 50),
    service-type: uint,
    contact-info: (string-ascii 100),
    verification-status: bool,
    priority-level: uint,
    registered-at: uint
  }
)

(define-map service-operators
  { operator: principal }
  { service-id: uint, authorized: bool }
)

(define-data-var next-service-id uint u1)

;; Register new emergency service
(define-public (register-emergency-service
  (service-name (string-ascii 50))
  (service-type uint)
  (contact-info (string-ascii 100))
  (priority-level uint))
  (let ((service-id (var-get next-service-id)))
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-some (map-get? service-operators { operator: tx-sender }))) ERR_UNAUTHORIZED)
    (asserts! (and (>= service-type SERVICE_TYPE_FIRE)
                   (<= service-type SERVICE_TYPE_RESCUE)) ERR_INVALID_SERVICE_TYPE)
    (asserts! (is-none (map-get? emergency-services { service-id: service-id })) ERR_SERVICE_ALREADY_EXISTS)

    (map-set emergency-services
      { service-id: service-id }
      {
        service-name: service-name,
        service-type: service-type,
        contact-info: contact-info,
        verification-status: false,
        priority-level: priority-level,
        registered-at: block-height
      })

    (var-set next-service-id (+ service-id u1))
    (ok service-id)))

;; Verify emergency service
(define-public (verify-service (service-id uint))
  (let ((service (unwrap! (map-get? emergency-services { service-id: service-id }) ERR_SERVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set emergency-services
      { service-id: service-id }
      (merge service { verification-status: true }))
    (ok true)))

;; Get service info
(define-read-only (get-service-info (service-id uint))
  (map-get? emergency-services { service-id: service-id }))

;; Check if service is verified
(define-read-only (is-service-verified (service-id uint))
  (match (map-get? emergency-services { service-id: service-id })
    service (get verification-status service)
    false))

;; Authorize service operator
(define-public (authorize-operator (operator principal) (service-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set service-operators
      { operator: operator }
      { service-id: service-id, authorized: true })
    (ok true)))
