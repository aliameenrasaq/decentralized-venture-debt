;; Venture Lender Smart Contract
;; Decentralized venture debt platform for startup financing
;; Revenue-based repayment with tokenized debt instruments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_INSUFFICIENT_FUNDS u102)
(define-constant ERR_LOAN_NOT_FOUND u103)
(define-constant ERR_INVALID_STATUS u104)
(define-constant ERR_POOR_CREDIT u105)

;; Loan Status
(define-constant STATUS_PENDING u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_FUNDED u3)
(define-constant STATUS_ACTIVE u4)
(define-constant STATUS_COMPLETED u5)
(define-constant STATUS_DEFAULTED u6)

;; Credit Tiers
(define-constant CREDIT_EXCELLENT u1)
(define-constant CREDIT_GOOD u2)
(define-constant CREDIT_FAIR u3)
(define-constant CREDIT_POOR u4)

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var next-investor-id uint u1)
(define-data-var total-loans-originated uint u0)
(define-data-var total-amount-funded uint u0)
(define-data-var platform-fee-rate uint u200) ;; 2% in basis points

;; Startup Profiles
(define-map startup-profiles
  principal
  {
    company-name: (string-ascii 100),
    industry: (string-ascii 50),
    monthly-revenue: uint,
    revenue-growth-rate: uint, ;; percentage
    burn-rate: uint,
    runway-months: uint,
    credit-score: uint,
    total-borrowed: uint,
    active-loans: uint,
    default-history: uint,
    registration-date: uint
  }
)

;; Loan Applications
(define-map loan-applications
  { loan-id: uint }
  {
    borrower: principal,
    loan-amount: uint,
    interest-rate: uint, ;; annual rate in basis points
    term-months: uint,
    revenue-share-rate: uint, ;; percentage of revenue
    minimum-monthly-payment: uint,
    purpose: (string-ascii 200),
    status: uint,
    application-date: uint,
    approval-date: (optional uint),
    funding-deadline: uint,
    total-funded: uint,
    repaid-amount: uint,
    next-payment-due: uint
  }
)

;; Investor Participation
(define-map investor-participation
  { loan-id: uint, investor: principal }
  {
    investment-amount: uint,
    participation-date: uint,
    tokens-received: uint,
    interest-earned: uint,
    principal-repaid: uint
  }
)

;; Debt Tokens (represents investor ownership in loans)
(define-map debt-tokens
  { token-id: uint }
  {
    loan-id: uint,
    holder: principal,
    principal-amount: uint,
    interest-rate: uint,
    issued-date: uint,
    maturity-date: uint,
    is-active: bool
  }
)

;; Revenue Reports (submitted by borrowers)
(define-map revenue-reports
  { borrower: principal, period: uint }
  {
    reported-revenue: uint,
    report-date: uint,
    verified: bool,
    payment-due: uint,
    payment-made: uint
  }
)

;; Platform Statistics
(define-map platform-stats
  { period: (string-ascii 20) }
  {
    loans-originated: uint,
    total-funded: uint,
    default-rate: uint, ;; in basis points
    average-interest-rate: uint,
    investor-returns: uint
  }
)

;; Authorized Underwriters
(define-map authorized-underwriters principal bool)

;; Counter maps
(define-map token-counter uint uint)
(define-map period-counter principal uint)

;; Read-only Functions

(define-read-only (get-startup-profile (startup principal))
  (map-get? startup-profiles startup)
)

(define-read-only (get-loan-application (loan-id uint))
  (map-get? loan-applications { loan-id: loan-id })
)

(define-read-only (get-investor-participation (loan-id uint) (investor principal))
  (map-get? investor-participation { loan-id: loan-id, investor: investor })
)

(define-read-only (get-debt-token (token-id uint))
  (map-get? debt-tokens { token-id: token-id })
)

(define-read-only (calculate-credit-score (monthly-revenue uint) (growth-rate uint) (burn-rate uint))
  (let
    (
      (revenue-factor (/ monthly-revenue u10000))
      (growth-factor (if (> growth-rate u20) u25 (/ growth-rate u4)))
      (burn-factor (if (< burn-rate monthly-revenue) u25 u0))
    )
    (+ (+ revenue-factor growth-factor) burn-factor)
  )
)

(define-read-only (calculate-interest-rate (credit-score uint))
  (if (>= credit-score u75) u800    ;; 8% for excellent credit
    (if (>= credit-score u60) u1200   ;; 12% for good credit
      (if (>= credit-score u40) u1800   ;; 18% for fair credit
        u2500)))  ;; 25% for poor credit
)

(define-read-only (calculate-revenue-payment (revenue uint) (revenue-share-rate uint))
  (/ (* revenue revenue-share-rate) u100)
)

(define-read-only (get-platform-stats-summary)
  {
    total-loans: (- (var-get next-loan-id) u1),
    total-funded: (var-get total-amount-funded),
    platform-fee-rate: (var-get platform-fee-rate)
  }
)

;; Public Functions

(define-public (register-startup
  (company-name (string-ascii 100))
  (industry (string-ascii 50))
  (monthly-revenue uint)
  (revenue-growth-rate uint)
  (burn-rate uint)
  (runway-months uint)
  )
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (credit-score (calculate-credit-score monthly-revenue revenue-growth-rate burn-rate))
    )
    (begin
      ;; Validation
      (asserts! (> monthly-revenue u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= revenue-growth-rate u1000) (err ERR_INVALID_AMOUNT)) ;; max 1000% growth
      
      ;; Register startup
      (map-set startup-profiles
        tx-sender
        {
          company-name: company-name,
          industry: industry,
          monthly-revenue: monthly-revenue,
          revenue-growth-rate: revenue-growth-rate,
          burn-rate: burn-rate,
          runway-months: runway-months,
          credit-score: credit-score,
          total-borrowed: u0,
          active-loans: u0,
          default-history: u0,
          registration-date: current-time
        }
      )
      
      (ok credit-score)
    )
  )
)

(define-public (apply-for-loan
  (loan-amount uint)
  (term-months uint)
  (revenue-share-rate uint)
  (purpose (string-ascii 200))
  )
  (let
    (
      (loan-id (var-get next-loan-id))
      (startup-profile (unwrap! (get-startup-profile tx-sender) (err ERR_NOT_AUTHORIZED)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (interest-rate (calculate-interest-rate (get credit-score startup-profile)))
      (minimum-payment (/ (* loan-amount interest-rate) (* u12 u10000))) ;; monthly interest
    )
    (begin
      ;; Validation
      (asserts! (> loan-amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (and (>= term-months u6) (<= term-months u60)) (err ERR_INVALID_AMOUNT))
      (asserts! (<= revenue-share-rate u50) (err ERR_INVALID_AMOUNT)) ;; max 50% revenue share
      (asserts! (>= (get credit-score startup-profile) u30) (err ERR_POOR_CREDIT))
      
      ;; Create loan application
      (map-set loan-applications
        { loan-id: loan-id }
        {
          borrower: tx-sender,
          loan-amount: loan-amount,
          interest-rate: interest-rate,
          term-months: term-months,
          revenue-share-rate: revenue-share-rate,
          minimum-monthly-payment: minimum-payment,
          purpose: purpose,
          status: STATUS_PENDING,
          application-date: current-time,
          approval-date: none,
          funding-deadline: (+ current-time u1209600), ;; 14 days to fund
          total-funded: u0,
          repaid-amount: u0,
          next-payment-due: u0
        }
      )
      
      ;; Update counters
      (var-set next-loan-id (+ loan-id u1))
      
      (ok loan-id)
    )
  )
)

(define-public (approve-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (get-loan-application loan-id) (err ERR_LOAN_NOT_FOUND)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (begin
      ;; Verify caller is authorized underwriter
      (asserts! (default-to false (map-get? authorized-underwriters tx-sender)) (err ERR_NOT_AUTHORIZED))
      ;; Verify loan is pending
      (asserts! (is-eq (get status loan) STATUS_PENDING) (err ERR_INVALID_STATUS))
      
      ;; Approve loan
      (map-set loan-applications
        { loan-id: loan-id }
        (merge loan {
          status: STATUS_APPROVED,
          approval-date: (some current-time)
        })
      )
      
      (ok true)
    )
  )
)

(define-public (invest-in-loan (loan-id uint) (investment-amount uint))
  (let
    (
      (loan (unwrap! (get-loan-application loan-id) (err ERR_LOAN_NOT_FOUND)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (token-id (+ (default-to u0 (map-get? token-counter u0)) u1))
      (remaining-amount (- (get loan-amount loan) (get total-funded loan)))
    )
    (begin
      ;; Validation
      (asserts! (is-eq (get status loan) STATUS_APPROVED) (err ERR_INVALID_STATUS))
      (asserts! (> investment-amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= investment-amount remaining-amount) (err ERR_INVALID_AMOUNT))
      (asserts! (< current-time (get funding-deadline loan)) (err ERR_INVALID_STATUS))
      
      ;; Record investor participation
      (map-set investor-participation
        { loan-id: loan-id, investor: tx-sender }
        {
          investment-amount: investment-amount,
          participation-date: current-time,
          tokens-received: investment-amount, ;; 1:1 ratio for simplicity
          interest-earned: u0,
          principal-repaid: u0
        }
      )
      
      ;; Issue debt token
      (map-set debt-tokens
        { token-id: token-id }
        {
          loan-id: loan-id,
          holder: tx-sender,
          principal-amount: investment-amount,
          interest-rate: (get interest-rate loan),
          issued-date: current-time,
          maturity-date: (+ current-time (* (get term-months loan) u2592000)), ;; convert months to seconds
          is-active: true
        }
      )
      
      ;; Update loan funding
      (let
        (
          (new-total-funded (+ (get total-funded loan) investment-amount))
        )
        (map-set loan-applications
          { loan-id: loan-id }
          (merge loan {
            total-funded: new-total-funded,
            status: (if (>= new-total-funded (get loan-amount loan)) STATUS_FUNDED STATUS_APPROVED)
          })
        )
      )
      
      ;; Update counters and platform stats
      (map-set token-counter u0 token-id)
      (var-set total-amount-funded (+ (var-get total-amount-funded) investment-amount))
      
      (ok token-id)
    )
  )
)

(define-public (submit-revenue-report (period uint) (reported-revenue uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (startup-profile (unwrap! (get-startup-profile tx-sender) (err ERR_NOT_AUTHORIZED)))
    )
    (begin
      ;; Validation
      (asserts! (> reported-revenue u0) (err ERR_INVALID_AMOUNT))
      
      ;; Calculate payment due based on active loans (simplified)
      (let
        (
          (payment-due (/ (* reported-revenue u10) u100)) ;; assume 10% revenue share average
        )
        
        ;; Record revenue report
        (map-set revenue-reports
          { borrower: tx-sender, period: period }
          {
            reported-revenue: reported-revenue,
            report-date: current-time,
            verified: false,
            payment-due: payment-due,
            payment-made: u0
          }
        )
      )
      
      (ok true)
    )
  )
)

(define-public (authorize-underwriter (underwriter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (ok (map-set authorized-underwriters underwriter true))
  )
)
