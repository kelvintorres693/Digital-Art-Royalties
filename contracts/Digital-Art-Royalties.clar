(define-non-fungible-token digital-art uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-insufficient-payment (err u103))
(define-constant err-invalid-royalty (err u104))
(define-constant err-token-not-found (err u105))
(define-constant err-already-listed (err u106))
(define-constant err-not-listed (err u107))

(define-data-var token-id-nonce uint u1)
(define-data-var platform-fee-percentage uint u250)

(define-map token-metadata
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        image-uri: (string-ascii 256),
        creator: principal,
        royalty-percentage: uint,
        created-at: uint,
    }
)

(define-map token-royalties
    uint
    {
        artist: principal,
        percentage: uint,
        total-earned: uint,
    }
)

(define-map listings
    uint
    {
        seller: principal,
        price: uint,
        listed-at: uint,
    }
)

(define-map user-balances
    principal
    uint
)

(define-public (mint-artwork
        (name (string-ascii 64))
        (description (string-ascii 256))
        (image-uri (string-ascii 256))
        (royalty-percentage uint)
    )
    (let ((token-id (var-get token-id-nonce)))
        (asserts! (<= royalty-percentage u1000) err-invalid-royalty)
        (try! (nft-mint? digital-art token-id tx-sender))
        (map-set token-metadata token-id {
            name: name,
            description: description,
            image-uri: image-uri,
            creator: tx-sender,
            royalty-percentage: royalty-percentage,
            created-at: stacks-block-height,
        })
        (map-set token-royalties token-id {
            artist: tx-sender,
            percentage: royalty-percentage,
            total-earned: u0,
        })
        (var-set token-id-nonce (+ token-id u1))
        (ok token-id)
    )
)

(define-public (list-artwork
        (token-id uint)
        (price uint)
    )
    (let ((token-owner (unwrap! (nft-get-owner? digital-art token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (asserts! (is-none (map-get? listings token-id)) err-already-listed)
        (map-set listings token-id {
            seller: tx-sender,
            price: price,
            listed-at: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (unlist-artwork (token-id uint))
    (let ((listing (unwrap! (map-get? listings token-id) err-listing-not-found)))
        (asserts! (is-eq tx-sender (get seller listing)) err-not-token-owner)
        (map-delete listings token-id)
        (ok true)
    )
)

(define-public (buy-artwork (token-id uint))
    (let (
            (listing (unwrap! (map-get? listings token-id) err-listing-not-found))
            (price (get price listing))
            (seller (get seller listing))
            (royalty-info (unwrap! (map-get? token-royalties token-id) err-token-not-found))
            (artist (get artist royalty-info))
            (royalty-percentage (get percentage royalty-info))
            (platform-fee (/ (* price (var-get platform-fee-percentage)) u10000))
            (royalty-amount (/ (* price royalty-percentage) u10000))
            (seller-amount (- (- price platform-fee) royalty-amount))
        )
        (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
        (try! (as-contract (stx-transfer? royalty-amount tx-sender artist)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (try! (nft-transfer? digital-art token-id seller tx-sender))
        (map-delete listings token-id)
        (map-set token-royalties token-id
            (merge royalty-info { total-earned: (+ (get total-earned royalty-info) royalty-amount) })
        )
        (map-set user-balances artist
            (+ (default-to u0 (map-get? user-balances artist)) royalty-amount)
        )
        (ok true)
    )
)

(define-public (transfer-artwork
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (nft-transfer? digital-art token-id sender recipient))
        (ok true)
    )
)

(define-public (update-royalty-percentage
        (token-id uint)
        (new-percentage uint)
    )
    (let ((metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found)))
        (asserts! (is-eq tx-sender (get creator metadata)) err-not-token-owner)
        (asserts! (<= new-percentage u1000) err-invalid-royalty)
        (map-set token-royalties token-id
            (merge
                (unwrap! (map-get? token-royalties token-id) err-token-not-found) { percentage: new-percentage }
            ))
        (ok true)
    )
)

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u1000) err-invalid-royalty)
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id)
)

(define-read-only (get-token-royalty-info (token-id uint))
    (map-get? token-royalties token-id)
)

(define-read-only (get-listing (token-id uint))
    (map-get? listings token-id)
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-token-owner (token-id uint))
    (nft-get-owner? digital-art token-id)
)

(define-read-only (get-last-token-id)
    (- (var-get token-id-nonce) u1)
)

(define-read-only (get-artwork-price (token-id uint))
    (match (map-get? listings token-id)
        listing (some (get price listing))
        none
    )
)

(define-read-only (is-artwork-listed (token-id uint))
    (is-some (map-get? listings token-id))
)

(define-read-only (get-artist-total-earnings (artist principal))
    (default-to u0 (map-get? user-balances artist))
)

(define-read-only (calculate-royalty-amount
        (token-id uint)
        (sale-price uint)
    )
    (match (map-get? token-royalties token-id)
        royalty-info (ok (/ (* sale-price (get percentage royalty-info)) u10000))
        (err err-token-not-found)
    )
)

(define-read-only (calculate-platform-fee (sale-price uint))
    (/ (* sale-price (var-get platform-fee-percentage)) u10000)
)

(define-read-only (get-artwork-history (token-id uint))
    (let (
            (metadata (map-get? token-metadata token-id))
            (royalty-info (map-get? token-royalties token-id))
            (listing (map-get? listings token-id))
        )
        {
            metadata: metadata,
            royalty-info: royalty-info,
            current-listing: listing,
            current-owner: (nft-get-owner? digital-art token-id),
        }
    )
)

(define-public (batch-mint (artworks (list 10
    {
    name: (string-ascii 64),
    description: (string-ascii 256),
    image-uri: (string-ascii 256),
    royalty-percentage: uint,
})))
    (fold mint-artwork-helper artworks (ok (list)))
)

(define-private (mint-artwork-helper
        (artwork {
            name: (string-ascii 64),
            description: (string-ascii 256),
            image-uri: (string-ascii 256),
            royalty-percentage: uint,
        })
        (acc (response (list 10 uint) uint))
    )
    (match acc
        success-list (match (mint-artwork (get name artwork) (get description artwork)
            (get image-uri artwork) (get royalty-percentage artwork)
        )
            token-id (ok (unwrap-panic (as-max-len? (append success-list token-id) u10)))
            error (err error)
        )
        error (err error)
    )
)

(define-public (emergency-withdraw)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender contract-owner)))
        (ok true)
    )
)
