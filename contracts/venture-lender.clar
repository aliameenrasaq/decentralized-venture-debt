;; Venture Lender Contract - Community-Funded Venture Debt Platform
;; Provides growth capital to startups with revenue-based repayment and tokenized debt instruments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_LOAN_NOT_FOUND u102)
(define-constant ERR_INSUFFICIENT_FUNDS u103)
(define-constant ERR_INVALID_STATUS u104)
(define-constant ERR_STARTUP_NOT_FOUND u105)
(define-constant ERR_INVESTOR_NOT_FOUND u106)
(define-constant ERR_LOAN_ALREADY_EXISTS u107)
(define-constant ERR_CREDIT_LIMIT_EXCEEDED u108)
(define-constant ERR_MINIMUM_REVENUE_NOT_MET u109)
(define-constant ERR_REPAYMENT_OVERDUE u110)

;; Loan Status Constants
(define-constant STATUS_PENDING u1)
(define-constant STATUS_APPROVED u2)
(define-constant STATUS_FUNDED u3)
(define-constant STATUS_ACTIVE u4)
(define-constant STATUS_REPAYING u5)
(define-constant STATUS_COMPLETED u6)
(define-constant STATUS_DEFAULTED u7)

;; Credit Rating Constants
(define-constant RATING_EXCELLENT u1)
(define-constant RATING_GOOD u2)
(define-constant RATING_FAIR u3)
(define-constant RATING_POOR u4)
(define-constant RATING_UNRATED u5)

;; Data Variables
(define-data-var next-loan-id uint u1)
(define-data-var next-startup-id uint u1)
(define-data-var next-token-id uint u1)
(define-data-var total-loans-originated uint u0)
(define-data-var total-capital-deployed uint u0)
(define-data-var total-returns-distributed uint u0)
(define-data-var platform-fee-rate uint u200) ;; 2.0%
(define-data-var min-loan-amount uint u10000) ;; Minimum $100 equivalent
(define-data-var max-loan-amount uint u500000000) ;; Maximum $5M equivalent
(define-data-var min-revenue-threshold uint u100000) ;; Minimum $1K monthly revenue

;; Startup Registry with Revenue Metrics
(define-map startups
  { startup-address: principal }
  {
    company-name: (string-ascii 100),
    business-model: (string-ascii 50),
    monthly-revenue: uint,
    revenue-growth-rate: uint,
    runway-months: uint,
    credit-score: uint,
    total-loans-requested: uint,
    total-loans-received: uint,
    current-debt-exposure: uint,
    repayment-history-score: uint,
    last-revenue-update: uint,
    registration-timestamp: uint,
    verification-status: bool,
    credit-limit: uint
  }
)

;; Revenue-Based Loan Registry
(define-map loans
  { loan-id: uint }
  {
    startup: principal,
    loan-amount: uint,
    funded-amount: uint,
    interest-rate: uint,
    revenue-percentage: uint,
    loan-term-months: uint,
    creation-timestamp: uint,
    approval-timestamp: uint,
    funding-timestamp: uint,
    maturity-timestamp: uint,
    status: uint,
    monthly-payment: uint,
    total-repaid: uint,
    remaining-balance: uint,
    last-payment-timestamp: uint,
    collateral-requirement: bool,
    debt-tokens-issued: uint,
    funding-pool: (optional principal)
  }
)

;; Tokenized Debt Instrument Registry
(define-map debt-tokens
  { token-id: uint }
  {
    loan-id: uint,
    token-amount: uint,
    owner: principal,
    purchase-price: uint,
    purchase-timestamp: uint,
    expected-return: uint,
    accrued-returns: uint,
    last-return-timestamp: uint,
    transferable: bool
  }
)

;; Investor Pool Management
(define-map investor-pools
  { pool-address: principal }
  {
    pool-name: (string-ascii 100),
    total-capital: uint,
    available-capital: uint,
    deployed-capital: uint,
    target-return-rate: uint,
    risk-tolerance: uint,
    active-investments: (list 50 uint),
    pool-investors: (list 25 principal),
    performance-metrics: { total-returns: uint, default-count: uint, success-rate: uint },
    minimum-investment: uint,
    creation-timestamp: uint
  }
)

;; Revenue Tracking for Repayments
(define-map revenue-reports
  { startup: principal, month: uint }
  {
    reported-revenue: uint,
    verification-timestamp: uint,
    verified-by: principal,
    growth-rate: uint,
    repayment-amount: uint
  }
)

;; Platform Analytics
(define-map platform-metrics
  { metric-period: (string-ascii 20) }
  {
    total-loans-originated: uint,
    total-volume-funded: uint,
    average-loan-size: uint,
    default-rate-percentage: uint,
    average-return-rate: uint,
    investor-count: uint,
    startup-count: uint
  }
)

;; Read-Only Functions
(define-read-only (get-startup-profile (startup-address principal))
  (map-get? startups { startup-address: startup-address })
)

(define-read-only (get-loan-details (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-debt-token-info (token-id uint))
  (map-get? debt-tokens { token-id: token-id })
)

(define-read-only (get-investor-pool-info (pool-address principal))
  (map-get? investor-pools { pool-address: pool-address })
)

(define-read-only (get-revenue-report (startup principal) (month uint))
  (map-get? revenue-reports { startup: startup, month: month })
)

(define-read-only (get-platform-statistics)
  {
    total-loans: (- (var-get next-loan-id) u1),
    total-startups: (- (var-get next-startup-id) u1),
    total-tokens: (- (var-get next-token-id) u1),
    loans-originated: (var-get total-loans-originated),
    capital-deployed: (var-get total-capital-deployed),
    returns-distributed: (var-get total-returns-distributed),
    platform-fee-rate: (var-get platform-fee-rate),
    min-loan: (var-get min-loan-amount),
    max-loan: (var-get max-loan-amount),
    min-revenue: (var-get min-revenue-threshold)
  }
)

;; Credit Assessment Function
(define-read-only (assess-startup-creditworthiness (startup-address principal))
  (match (map-get? startups { startup-address: startup-address })
    startup-data
      (let
        (
          (revenue (get monthly-revenue startup-data))
          (growth-rate (get revenue-growth-rate startup-data))
          (repayment-history (get repayment-history-score startup-data))
          (current-exposure (get current-debt-exposure startup-data))
          (credit-limit (get credit-limit startup-data))
        )
        {
          credit-score: (+ (+ repayment-history (/ revenue u1000)) (/ growth-rate u10)),
          recommended-amount: (/ (* revenue u12) u100), ;; 12% of annual revenue
          risk-level: (if (< repayment-history u300) u4 (if (< repayment-history u500) u3 (if (< repayment-history u700) u2 u1))),
          available-credit: (if (> credit-limit current-exposure) (- credit-limit current-exposure) u0)
        }
      )
    { credit-score: u0, recommended-amount: u0, risk-level: u5, available-credit: u0 }
  )
)

;; Revenue-Based Payment Calculation
(define-read-only (calculate-revenue-payment 
  (loan-id uint)
  (monthly-revenue uint)
  )
  (match (map-get? loans { loan-id: loan-id })
    loan-data
      (let
        (
          (revenue-percentage (get revenue-percentage loan-data))
          (remaining-balance (get remaining-balance loan-data))
          (payment-amount (/ (* monthly-revenue revenue-percentage) u10000))
        )
        {
          payment-amount: payment-amount,
          remaining-after-payment: (if (> remaining-balance payment-amount) (- remaining-balance payment-amount) u0),
          loan-completion-status: (if (<= remaining-balance payment-amount) true false)
        }
      )
    { payment-amount: u0, remaining-after-payment: u0, loan-completion-status: false }
  )
)

;; Public Functions

;; Register Startup with Revenue Metrics
(define-public (register-startup
  (company-name (string-ascii 100))
  (business-model (string-ascii 50))
  (monthly-revenue uint)
  (revenue-growth-rate uint)
  (runway-months uint)
  )
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (startup-id (var-get next-startup-id))
    )
    (begin
      (asserts! (>= monthly-revenue (var-get min-revenue-threshold)) (err ERR_MINIMUM_REVENUE_NOT_MET))
      (asserts! (> runway-months u0) (err ERR_INVALID_AMOUNT))
      
      (map-set startups
        { startup-address: tx-sender }
        {
          company-name: company-name,
          business-model: business-model,
          monthly-revenue: monthly-revenue,
          revenue-growth-rate: revenue-growth-rate,
          runway-months: runway-months,
          credit-score: u500, ;; Default credit score
          total-loans-requested: u0,
          total-loans-received: u0,
          current-debt-exposure: u0,
          repayment-history-score: u500, ;; Neutral starting score
          last-revenue-update: current-time,
          registration-timestamp: current-time,
          verification-status: false,
          credit-limit: (* monthly-revenue u24) ;; 24x monthly revenue credit limit
        }
      )
      
      (var-set next-startup-id (+ startup-id u1))
      (ok startup-id)
    )
  )
)

;; Create Revenue-Based Loan Request
(define-public (request-loan
  (loan-amount uint)
  (revenue-percentage uint)
  (loan-term-months uint)
  (collateral-required bool)
  )
  (let
    (
      (loan-id (var-get next-loan-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (startup-data (unwrap! (map-get? startups { startup-address: tx-sender }) (err ERR_STARTUP_NOT_FOUND)))
      (credit-assessment (assess-startup-creditworthiness tx-sender))
    )
    (begin
      (asserts! (>= loan-amount (var-get min-loan-amount)) (err ERR_INVALID_AMOUNT))
      (asserts! (<= loan-amount (var-get max-loan-amount)) (err ERR_INVALID_AMOUNT))
      (asserts! (<= loan-amount (get available-credit credit-assessment)) (err ERR_CREDIT_LIMIT_EXCEEDED))
      (asserts! (> revenue-percentage u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= revenue-percentage u1000) (err ERR_INVALID_AMOUNT)) ;; Max 10%
      (asserts! (> loan-term-months u0) (err ERR_INVALID_AMOUNT))
      
      (map-set loans
        { loan-id: loan-id }
        {
          startup: tx-sender,
          loan-amount: loan-amount,
          funded-amount: u0,
          interest-rate: u1200, ;; 12% annual default rate
          revenue-percentage: revenue-percentage,
          loan-term-months: loan-term-months,
          creation-timestamp: current-time,
          approval-timestamp: u0,
          funding-timestamp: u0,
          maturity-timestamp: (+ current-time (* loan-term-months u2592000)), ;; 30 days per month
          status: STATUS_PENDING,
          monthly-payment: u0,
          total-repaid: u0,
          remaining-balance: u0,
          last-payment-timestamp: u0,
          collateral-requirement: collateral-required,
          debt-tokens-issued: u0,
          funding-pool: none
        }
      )
      
      ;; Update startup loan request count
      (map-set startups
        { startup-address: tx-sender }
        (merge startup-data { total-loans-requested: (+ (get total-loans-requested startup-data) u1) })
      )
      
      (var-set next-loan-id (+ loan-id u1))
      (ok loan-id)
    )
  )
)

;; Fund Approved Loan
(define-public (fund-loan
  (loan-id uint)
  (funding-pool-address (optional principal))
  )
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) (err ERR_LOAN_NOT_FOUND)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (loan-amount (get loan-amount loan))
      (startup-address (get startup loan))
      (startup-data (unwrap! (map-get? startups { startup-address: startup-address }) (err ERR_STARTUP_NOT_FOUND)))
    )
    (begin
      (asserts! (is-eq (get status loan) STATUS_APPROVED) (err ERR_INVALID_STATUS))
      (asserts! (>= (stx-get-balance tx-sender) loan-amount) (err ERR_INSUFFICIENT_FUNDS))
      
      ;; Transfer funds to startup
      (try! (stx-transfer? loan-amount tx-sender startup-address))
      
      ;; Update loan status to funded
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          status: STATUS_FUNDED,
          funded-amount: loan-amount,
          funding-timestamp: current-time,
          remaining-balance: loan-amount,
          funding-pool: funding-pool-address
        })
      )
      
      ;; Update startup debt exposure
      (map-set startups
        { startup-address: startup-address }
        (merge startup-data {
          current-debt-exposure: (+ (get current-debt-exposure startup-data) loan-amount),
          total-loans-received: (+ (get total-loans-received startup-data) u1)
        })
      )
      
      ;; Update platform statistics
      (var-set total-loans-originated (+ (var-get total-loans-originated) u1))
      (var-set total-capital-deployed (+ (var-get total-capital-deployed) loan-amount))
      
      (ok loan-amount)
    )
  )
)

;; Process Revenue-Based Repayment
(define-public (process-repayment
  (loan-id uint)
  (monthly-revenue uint)
  )
  (let
    (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) (err ERR_LOAN_NOT_FOUND)))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (payment-calc (calculate-revenue-payment loan-id monthly-revenue))
      (payment-amount (get payment-amount payment-calc))
      (startup-data (unwrap! (map-get? startups { startup-address: (get startup loan) }) (err ERR_STARTUP_NOT_FOUND)))
    )
    (begin
      (asserts! (is-eq (get startup loan) tx-sender) (err ERR_NOT_AUTHORIZED))
      (asserts! (or (is-eq (get status loan) STATUS_FUNDED) (is-eq (get status loan) STATUS_ACTIVE)) (err ERR_INVALID_STATUS))
      (asserts! (>= (stx-get-balance tx-sender) payment-amount) (err ERR_INSUFFICIENT_FUNDS))
      
      ;; Transfer payment to contract for distribution
      (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
      
      ;; Update loan with payment
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          status: (if (get loan-completion-status payment-calc) STATUS_COMPLETED STATUS_ACTIVE),
          total-repaid: (+ (get total-repaid loan) payment-amount),
          remaining-balance: (get remaining-after-payment payment-calc),
          last-payment-timestamp: current-time
        })
      )
      
      ;; Record revenue report
      (map-set revenue-reports
        { startup: tx-sender, month: (/ current-time u2592000) }
        {
          reported-revenue: monthly-revenue,
          verification-timestamp: current-time,
          verified-by: tx-sender,
          growth-rate: (if (> monthly-revenue (get monthly-revenue startup-data)) 
                         (/ (* (- monthly-revenue (get monthly-revenue startup-data)) u100) (get monthly-revenue startup-data)) 
                         u0),
          repayment-amount: payment-amount
        }
      )
      
      ;; Update startup revenue data
      (map-set startups
        { startup-address: tx-sender }
        (merge startup-data {
          monthly-revenue: monthly-revenue,
          last-revenue-update: current-time,
          current-debt-exposure: (if (get loan-completion-status payment-calc) 
                                   (- (get current-debt-exposure startup-data) (get loan-amount loan))
                                   (get current-debt-exposure startup-data))
        })
      )
      
      (var-set total-returns-distributed (+ (var-get total-returns-distributed) payment-amount))
      (ok payment-amount)
    )
  )
)

;; Issue Tokenized Debt Instrument
(define-public (issue-debt-token
  (loan-id uint)
  (token-amount uint)
  (expected-return uint)
  )
  (let
    (
      (token-id (var-get next-token-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) (err ERR_LOAN_NOT_FOUND)))
    )
    (begin
      (asserts! (is-eq (get status loan) STATUS_FUNDED) (err ERR_INVALID_STATUS))
      (asserts! (> token-amount u0) (err ERR_INVALID_AMOUNT))
      
      (map-set debt-tokens
        { token-id: token-id }
        {
          loan-id: loan-id,
          token-amount: token-amount,
          owner: tx-sender,
          purchase-price: token-amount,
          purchase-timestamp: current-time,
          expected-return: expected-return,
          accrued-returns: u0,
          last-return-timestamp: current-time,
          transferable: true
        }
      )
      
      ;; Update loan with token issuance
      (map-set loans
        { loan-id: loan-id }
        (merge loan {
          debt-tokens-issued: (+ (get debt-tokens-issued loan) u1)
        })
      )
      
      (var-set next-token-id (+ token-id u1))
      (ok token-id)
    )
  )
)

;; title: venture-lender
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

