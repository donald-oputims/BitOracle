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