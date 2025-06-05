;; Backup System Contract
;; Manages emergency communication backups

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_BACKUP_NOT_FOUND (err u401))
(define-constant ERR_BACKUP_ALREADY_EXISTS (err u402))
(define-constant ERR_INVALID_BACKUP_TYPE (err u403))

;; Backup types
(define-constant BACKUP_TYPE_SATELLITE u1)
(define-constant BACKUP_TYPE_MESH u2)
(define-constant BACKUP_TYPE_RADIO u3)
(define-constant BACKUP_TYPE_CELLULAR u4)

;; Backup status
(define-constant BACKUP_STATUS_STANDBY u1)
(define-constant BACKUP_STATUS_ACTIVE u2)
(define-constant BACKUP_STATUS_FAILED u3)

;; Data structures
(define-map backup-channels
  { channel-id: uint }
  {
    channel-name: (string-ascii 50),
    backup-type: uint,
    capacity: uint,
    current-load: uint,
    status: uint,
    last-tested: uint,
    reliability-score: uint
  }
)

(define-map backup-activations
  { activation-id: uint }
  {
    channel-id: uint,
    activated-by: principal,
    activation-time: uint,
    reason: (string-ascii 100),
    duration: uint
  }
)

(define-data-var next-channel-id uint u1)
(define-data-var next-activation-id uint u1)
(define-data-var backup-mode-active bool false)

;; Register backup channel
(define-public (register-backup-channel
  (channel-name (string-ascii 50))
  (backup-type uint)
  (capacity uint))
  (let ((channel-id (var-get next-channel-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (>= backup-type BACKUP_TYPE_SATELLITE)
                   (<= backup-type BACKUP_TYPE_CELLULAR)) ERR_INVALID_BACKUP_TYPE)
    (asserts! (is-none (map-get? backup-channels { channel-id: channel-id })) ERR_BACKUP_ALREADY_EXISTS)

    (map-set backup-channels
      { channel-id: channel-id }
      {
        channel-name: channel-name,
        backup-type: backup-type,
        capacity: capacity,
        current-load: u0,
        status: BACKUP_STATUS_STANDBY,
        last-tested: block-height,
        reliability-score: u100
      })

    (var-set next-channel-id (+ channel-id u1))
    (ok channel-id)))

;; Activate backup channel
(define-public (activate-backup-channel
  (channel-id uint)
  (reason (string-ascii 100)))
  (let ((channel (unwrap! (map-get? backup-channels { channel-id: channel-id }) ERR_BACKUP_NOT_FOUND))
        (activation-id (var-get next-activation-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    ;; Update channel status
    (map-set backup-channels
      { channel-id: channel-id }
      (merge channel { status: BACKUP_STATUS_ACTIVE }))

    ;; Record activation
    (map-set backup-activations
      { activation-id: activation-id }
      {
        channel-id: channel-id,
        activated-by: tx-sender,
        activation-time: block-height,
        reason: reason,
        duration: u0
      })

    (var-set next-activation-id (+ activation-id u1))
    (var-set backup-mode-active true)
    (ok activation-id)))

;; Deactivate backup channel
(define-public (deactivate-backup-channel (channel-id uint))
  (let ((channel (unwrap! (map-get? backup-channels { channel-id: channel-id }) ERR_BACKUP_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set backup-channels
      { channel-id: channel-id }
      (merge channel {
        status: BACKUP_STATUS_STANDBY,
        current-load: u0
      }))

    (ok true)))

;; Test backup channel
(define-public (test-backup-channel (channel-id uint))
  (let ((channel (unwrap! (map-get? backup-channels { channel-id: channel-id }) ERR_BACKUP_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set backup-channels
      { channel-id: channel-id }
      (merge channel { last-tested: block-height }))

    (ok true)))

;; Get backup channel info
(define-read-only (get-backup-channel-info (channel-id uint))
  (map-get? backup-channels { channel-id: channel-id }))

;; Get backup system status
(define-read-only (get-backup-system-status)
  {
    backup-mode-active: (var-get backup-mode-active),
    total-channels: (var-get next-channel-id),
    active-channels: (count-active-backups)
  })

;; Count active backup channels (simplified)
(define-private (count-active-backups)
  u0) ;; Simplified for demo

;; Check if backup mode is active
(define-read-only (is-backup-mode-active)
  (var-get backup-mode-active))
