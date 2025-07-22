;; Debt Sustainability Monitoring Contract
;; Tracks government debt levels and intergenerational burden

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INVALID-INPUT (err u301))
(define-constant ERR-ENTITY-NOT-FOUND (err u302))
(define-constant ERR-DEBT-LIMIT-EXCEEDED (err u303))

;; Data Variables
(define-data-var next-entity-id uint u1)
(define-data-var global-debt-limit uint u10000000000) ;; 10 billion units
(define-data-var sustainability-threshold uint u60) ;; 60% debt-to-GDP ratio

;; Data Maps
(define-map debt-entities
  { entity-id: uint }
  {
    name: (string-ascii 100),
    entity-type: (string-ascii 50),
    country: (string-ascii 50),
    total-debt: uint,
    gdp: uint,
    population: uint,
    debt-per-capita: uint,
    last-updated: uint,
    credit-rating: (string-ascii 10),
    authorized-reporter: principal
  }
)

(define-map debt-records
  { entity-id: uint, record-date: uint }
  {
    debt-amount: uint,
    debt-type: (string-ascii 50),
    interest-rate: uint,
    maturity-years: uint,
    currency: (string-ascii 10),
    purpose: (string-ascii 200),
    reporter: principal,
    verified: bool
  }
)

(define-map sustainability-metrics
  { entity-id: uint, metric-date: uint }
  {
    debt-to-gdp-ratio: uint,
    debt-service-ratio: uint,
    fiscal-balance: int,
    primary-balance: int,
    sustainability-score: uint,
    risk-level: (string-ascii 20),
    future-burden-index: uint
  }
)

(define-map intergenerational-impact
  { entity-id: uint }
  {
    current-generation-burden: uint,
    next-generation-burden: uint,
    long-term-projection: uint,
    burden-shift-rate: uint,
    sustainability-years: uint,
    mitigation-measures: (string-ascii 300)
  }
)

(define-map debt-alerts
  { alert-id: uint }
  {
    entity-id: uint,
    alert-type: (string-ascii 50),
    severity: (string-ascii 20),
    message: (string-ascii 200),
    triggered-at: uint,
    resolved: bool,
    resolution-date: uint
  }
)

;; Public Functions

;; Register debt entity
(define-public (register-entity (name (string-ascii 100)) (entity-type (string-ascii 50)) (country (string-ascii 50)) (gdp uint) (population uint))
  (begin
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len entity-type) u0) ERR-INVALID-INPUT)
    (asserts! (> gdp u0) ERR-INVALID-INPUT)
    (asserts! (> population u0) ERR-INVALID-INPUT)

    (let ((entity-id (var-get next-entity-id)))
      (map-set debt-entities
        { entity-id: entity-id }
        {
          name: name,
          entity-type: entity-type,
          country: country,
          total-debt: u0,
          gdp: gdp,
          population: population,
          debt-per-capita: u0,
          last-updated: block-height,
          credit-rating: "NR",
          authorized-reporter: tx-sender
        }
      )

      (var-set next-entity-id (+ entity-id u1))
      (ok entity-id)
    )
  )
)

;; Record debt transaction
(define-public (record-debt (entity-id uint) (amount uint) (debt-type (string-ascii 50)) (interest-rate uint) (maturity uint) (currency (string-ascii 10)) (purpose (string-ascii 200)))
  (let ((entity (unwrap! (map-get? debt-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get authorized-reporter entity)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> (len debt-type) u0) ERR-INVALID-INPUT)
    (asserts! (<= interest-rate u10000) ERR-INVALID-INPUT) ;; Max 100% interest rate

    ;; Check debt limit
    (let ((new-total-debt (+ (get total-debt entity) amount)))
      (asserts! (<= new-total-debt (var-get global-debt-limit)) ERR-DEBT-LIMIT-EXCEEDED)

      (map-set debt-records
        { entity-id: entity-id, record-date: block-height }
        {
          debt-amount: amount,
          debt-type: debt-type,
          interest-rate: interest-rate,
          maturity-years: maturity,
          currency: currency,
          purpose: purpose,
          reporter: tx-sender,
          verified: false
        }
      )

      ;; Update entity totals
      (map-set debt-entities
        { entity-id: entity-id }
        (merge entity {
          total-debt: new-total-debt,
          debt-per-capita: (/ new-total-debt (get population entity)),
          last-updated: block-height
        })
      )

      (ok true)
    )
  )
)

;; Calculate sustainability metrics
(define-public (calculate-sustainability (entity-id uint) (fiscal-balance int) (primary-balance int))
  (let ((entity (unwrap! (map-get? debt-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get authorized-reporter entity)) ERR-NOT-AUTHORIZED)

    (let ((debt-to-gdp (/ (* (get total-debt entity) u100) (get gdp entity)))
          (sustainability-score (if (<= debt-to-gdp (var-get sustainability-threshold)) u100 (- u100 (- debt-to-gdp (var-get sustainability-threshold)))))
          (risk-level (if (> debt-to-gdp u80) "high" (if (> debt-to-gdp u60) "medium" "low"))))

      (map-set sustainability-metrics
        { entity-id: entity-id, metric-date: block-height }
        {
          debt-to-gdp-ratio: debt-to-gdp,
          debt-service-ratio: (/ (* (get total-debt entity) u5) (get gdp entity)), ;; Assuming 5% average interest
          fiscal-balance: fiscal-balance,
          primary-balance: primary-balance,
          sustainability-score: sustainability-score,
          risk-level: risk-level,
          future-burden-index: (/ debt-to-gdp u2) ;; Simplified calculation
        }
      )

      ;; Trigger alert if necessary
      (begin
        (if (> debt-to-gdp (var-get sustainability-threshold))
          (begin
            (try! (create-alert entity-id "debt-threshold" "warning" "Debt-to-GDP ratio exceeded sustainability threshold"))
            (ok true)
          )
          (ok true)
        )
      )
    )
  )
)

;; Update intergenerational impact
(define-public (update-intergenerational-impact (entity-id uint) (current-burden uint) (next-burden uint) (projection uint) (shift-rate uint) (years uint) (measures (string-ascii 300)))
  (let ((entity (unwrap! (map-get? debt-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get authorized-reporter entity)) ERR-NOT-AUTHORIZED)
    (asserts! (> years u0) ERR-INVALID-INPUT)

    (map-set intergenerational-impact
      { entity-id: entity-id }
      {
        current-generation-burden: current-burden,
        next-generation-burden: next-burden,
        long-term-projection: projection,
        burden-shift-rate: shift-rate,
        sustainability-years: years,
        mitigation-measures: measures
      }
    )

    (ok true)
  )
)

;; Create debt alert
(define-public (create-alert (entity-id uint) (alert-type (string-ascii 50)) (severity (string-ascii 20)) (message (string-ascii 200)))
  (begin
    (asserts! (is-some (map-get? debt-entities { entity-id: entity-id })) ERR-ENTITY-NOT-FOUND)
    (asserts! (> (len alert-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len message) u0) ERR-INVALID-INPUT)

    (let ((alert-id (var-get next-entity-id)))
      (map-set debt-alerts
        { alert-id: alert-id }
        {
          entity-id: entity-id,
          alert-type: alert-type,
          severity: severity,
          message: message,
          triggered-at: block-height,
          resolved: false,
          resolution-date: u0
        }
      )

      (var-set next-entity-id (+ alert-id u1))
      (ok alert-id)
    )
  )
)

;; Resolve alert
(define-public (resolve-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? debt-alerts { alert-id: alert-id }) ERR-ENTITY-NOT-FOUND)))

    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set debt-alerts
      { alert-id: alert-id }
      (merge alert {
        resolved: true,
        resolution-date: block-height
      })
    )

    (ok true)
  )
)

;; Update credit rating
(define-public (update-credit-rating (entity-id uint) (rating (string-ascii 10)))
  (let ((entity (unwrap! (map-get? debt-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))

    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len rating) u0) ERR-INVALID-INPUT)

    (map-set debt-entities
      { entity-id: entity-id }
      (merge entity { credit-rating: rating })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get debt entity
(define-read-only (get-debt-entity (entity-id uint))
  (map-get? debt-entities { entity-id: entity-id })
)

;; Get debt record
(define-read-only (get-debt-record (entity-id uint) (record-date uint))
  (map-get? debt-records { entity-id: entity-id, record-date: record-date })
)

;; Get sustainability metrics
(define-read-only (get-sustainability-metrics (entity-id uint) (metric-date uint))
  (map-get? sustainability-metrics { entity-id: entity-id, metric-date: metric-date })
)

;; Get intergenerational impact
(define-read-only (get-intergenerational-impact (entity-id uint))
  (map-get? intergenerational-impact { entity-id: entity-id })
)

;; Get debt alert
(define-read-only (get-debt-alert (alert-id uint))
  (map-get? debt-alerts { alert-id: alert-id })
)

;; Get sustainability threshold
(define-read-only (get-sustainability-threshold)
  (var-get sustainability-threshold)
)

;; Check debt sustainability
(define-read-only (check-debt-sustainability (entity-id uint))
  (match (map-get? debt-entities { entity-id: entity-id })
    entity
      (let ((debt-to-gdp (/ (* (get total-debt entity) u100) (get gdp entity))))
        (<= debt-to-gdp (var-get sustainability-threshold))
      )
    false
  )
)

;; Calculate debt burden per capita
(define-read-only (calculate-debt-per-capita (entity-id uint))
  (match (map-get? debt-entities { entity-id: entity-id })
    entity (/ (get total-debt entity) (get population entity))
    u0
  )
)
