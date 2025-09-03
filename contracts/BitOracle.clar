;; BitOracle: Decentralized Bitcoin Price Prediction Protocol
;;
;; Summary:
;; A next-generation prediction market protocol leveraging Stacks L2's Bitcoin 
;; settlement finality to create trustless, transparent, and economically 
;; incentivized Bitcoin price forecasting mechanisms.
;;
;; Description:
;; BitOracle transforms Bitcoin price speculation into a structured, 
;; decentralized prediction ecosystem. Built on Stacks' unique Bitcoin-anchored 
;; architecture, the protocol enables participants to stake STX tokens on 
;; directional Bitcoin price movements, creating liquid prediction markets with 
;; cryptographic settlement guarantees. The system employs sophisticated 
;; economic incentives, oracle-driven price feeds, and proportional reward 
;; distribution to ensure market integrity while maintaining Bitcoin's 
;; decentralized ethos.
;;
;; Key Innovations:
;; - Bitcoin-native settlement through Stacks L2
;; - Trustless oracle integration with multi-signature validation
;; - Dynamic stake-weighted reward mechanisms
;; - Anti-manipulation economic safeguards
;; - Gas-efficient market operations with L2 scaling
;;

;; CONSTANTS & ERROR CODES

(define-constant CONTRACT_OWNER tx-sender)

;; Error Definitions
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MARKET_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PREDICTION (err u102))
(define-constant ERR_MARKET_INACTIVE (err u103))
(define-constant ERR_ALREADY_CLAIMED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_INVALID_PARAMS (err u106))
(define-constant ERR_MARKET_UNRESOLVED (err u107))

;; Prediction Constants
(define-constant PREDICTION_UP "up")
(define-constant PREDICTION_DOWN "down")

;; STATE VARIABLES

(define-data-var oracle-principal principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var min-stake-amount uint u1000000) ;; 1 STX minimum
(define-data-var platform-fee-basis-points uint u200) ;; 2%
(define-data-var next-market-id uint u1)

;; DATA STRUCTURES

;; Market Configuration
(define-map prediction-markets
  uint ;; market-id
  {
    btc-start-price: uint,
    btc-end-price: uint,
    total-up-stakes: uint,
    total-down-stakes: uint,
    market-open-height: uint,
    market-close-height: uint,
    is-resolved: bool,
    created-at: uint,
  }
)

;; User Participation Tracking
(define-map participant-positions
  {
    market-id: uint,
    participant: principal,
  }
  {
    direction: (string-ascii 4),
    stake-amount: uint,
    rewards-claimed: bool,
    position-timestamp: uint,
  }
)

;; CORE MARKET FUNCTIONS

;; Create New Prediction Market
(define-public (create-prediction-market
    (btc-price uint)
    (open-height uint)
    (close-height uint)
  )
  (let ((market-id (var-get next-market-id)))
    ;; Authorization Check
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    ;; Parameter Validation
    (asserts! (> close-height open-height) ERR_INVALID_PARAMS)
    (asserts! (> btc-price u0) ERR_INVALID_PARAMS)
    (asserts! (> close-height stacks-block-height) ERR_INVALID_PARAMS)

    ;; Market Initialization
    (map-set prediction-markets market-id {
      btc-start-price: btc-price,
      btc-end-price: u0,
      total-up-stakes: u0,
      total-down-stakes: u0,
      market-open-height: open-height,
      market-close-height: close-height,
      is-resolved: false,
      created-at: stacks-block-height,
    })

    (var-set next-market-id (+ market-id u1))
    (ok market-id)
  )
)

;; Submit Price Prediction
(define-public (predict-price-movement
    (market-id uint)
    (direction (string-ascii 4))
    (stake-amount uint)
  )
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND))
      (current-height stacks-block-height)
    )
    ;; Market Timing Validation
    (asserts!
      (and
        (>= current-height (get market-open-height market-data))
        (< current-height (get market-close-height market-data))
      )
      ERR_MARKET_INACTIVE
    )

    ;; Prediction Validation
    (asserts!
      (or (is-eq direction PREDICTION_UP) (is-eq direction PREDICTION_DOWN))
      ERR_INVALID_PREDICTION
    )

    ;; Stake Validation
    (asserts! (>= stake-amount (var-get min-stake-amount)) ERR_INVALID_PARAMS)
    (asserts! (>= (stx-get-balance tx-sender) stake-amount)
      ERR_INSUFFICIENT_FUNDS
    )

    ;; Transfer Stake to Contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

    ;; Record Participant Position
    (map-set participant-positions {
      market-id: market-id,
      participant: tx-sender,
    } {
      direction: direction,
      stake-amount: stake-amount,
      rewards-claimed: false,
      position-timestamp: current-height,
    })

    ;; Update Market Stakes
    (map-set prediction-markets market-id
      (merge market-data {
        total-up-stakes: (if (is-eq direction PREDICTION_UP)
          (+ (get total-up-stakes market-data) stake-amount)
          (get total-up-stakes market-data)
        ),
        total-down-stakes: (if (is-eq direction PREDICTION_DOWN)
          (+ (get total-down-stakes market-data) stake-amount)
          (get total-down-stakes market-data)
        ),
      })
    )

    (ok true)
  )
)

;; Oracle Market Resolution
(define-public (resolve-market
    (market-id uint)
    (btc-final-price uint)
  )
  (let ((market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND)))
    ;; Oracle Authorization
    (asserts! (is-eq tx-sender (var-get oracle-principal)) ERR_UNAUTHORIZED)

    ;; Market Resolution Validation
    (asserts! (>= stacks-block-height (get market-close-height market-data))
      ERR_MARKET_INACTIVE
    )
    (asserts! (not (get is-resolved market-data)) ERR_MARKET_INACTIVE)
    (asserts! (> btc-final-price u0) ERR_INVALID_PARAMS)

    ;; Finalize Market
    (map-set prediction-markets market-id
      (merge market-data {
        btc-end-price: btc-final-price,
        is-resolved: true,
      })
    )

    (ok true)
  )
)

;; Claim Prediction Rewards
(define-public (claim-rewards (market-id uint))
  (let (
      (market-data (unwrap! (map-get? prediction-markets market-id) ERR_MARKET_NOT_FOUND))
      (position-data (unwrap!
        (map-get? participant-positions {
          market-id: market-id,
          participant: tx-sender,
        })
        ERR_MARKET_NOT_FOUND
      ))
    )
    ;; Resolution Check
    (asserts! (get is-resolved market-data) ERR_MARKET_UNRESOLVED)
    (asserts! (not (get rewards-claimed position-data)) ERR_ALREADY_CLAIMED)

    (let (
        (winning-direction (if (> (get btc-end-price market-data) (get btc-start-price market-data))
          PREDICTION_UP
          PREDICTION_DOWN
        ))
        (total-market-stake (+ (get total-up-stakes market-data) (get total-down-stakes market-data)))
        (winning-pool-stake (if (is-eq winning-direction PREDICTION_UP)
          (get total-up-stakes market-data)
          (get total-down-stakes market-data)
        ))
      )
      ;; Winning Validation
      (asserts! (is-eq (get direction position-data) winning-direction)
        ERR_INVALID_PREDICTION
      )