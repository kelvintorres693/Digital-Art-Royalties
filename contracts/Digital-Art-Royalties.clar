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
(define-constant err-collection-not-found (err u108))
(define-constant err-not-collection-creator (err u109))
(define-constant err-artwork-already-in-collection (err u110))
(define-constant err-collection-full (err u111))
(define-constant err-invalid-collection-bonus (err u112))

(define-data-var token-id-nonce uint u1)
(define-data-var platform-fee-percentage uint u250)
(define-data-var provenance-entry-nonce uint u1)
(define-data-var collection-id-nonce uint u1)

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

(define-map artwork-provenance
    uint
    {
        entry-id: uint,
        token-id: uint,
        from-owner: principal,
        to-owner: principal,
        transaction-type: (string-ascii 16),
        price: uint,
        timestamp: uint,
        next-entry: (optional uint),
    }
)

(define-map token-provenance-head
    uint
    uint
)

;; Collection System Maps
(define-map collections
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        creator: principal,
        created-at: uint,
        artwork-count: uint,
        royalty-bonus: uint, ;; Additional percentage for collection sales
        is-active: bool,
    }
)

(define-map collection-artworks
    {collection-id: uint, token-id: uint}
    bool
)

(define-map artwork-collection
    uint ;; token-id
    uint ;; collection-id
)

(define-map user-collections
    principal
    (list 20 uint)
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
        (unwrap-panic (record-provenance-entry token-id (as-contract tx-sender) tx-sender
            "mint" u0
        ))
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
        (unwrap-panic (record-provenance-entry token-id seller tx-sender "sale" price))
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
        (unwrap-panic (record-provenance-entry token-id sender recipient "transfer" u0))
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

(define-private (record-provenance-entry
        (token-id uint)
        (from-owner principal)
        (to-owner principal)
        (transaction-type (string-ascii 16))
        (price uint)
    )
    (let (
            (entry-id (var-get provenance-entry-nonce))
            (current-head (map-get? token-provenance-head token-id))
        )
        (map-set artwork-provenance entry-id {
            entry-id: entry-id,
            token-id: token-id,
            from-owner: from-owner,
            to-owner: to-owner,
            transaction-type: transaction-type,
            price: price,
            timestamp: stacks-block-height,
            next-entry: current-head,
        })
        (map-set token-provenance-head token-id entry-id)
        (var-set provenance-entry-nonce (+ entry-id u1))
        (ok true)
    )
)

(define-read-only (get-artwork-provenance (token-id uint))
    (map-get? token-provenance-head token-id)
)

(define-read-only (get-provenance-entry (entry-id uint))
    (map-get? artwork-provenance entry-id)
)

(define-read-only (get-provenance-count)
    (- (var-get provenance-entry-nonce) u1)
)

(define-public (batch-mint (artworks (list
    10
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        image-uri: (string-ascii 256),
        royalty-percentage: uint,
    }
)))
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

;; Collection Management Functions
(define-public (create-collection
        (name (string-ascii 64))
        (description (string-ascii 256))
        (royalty-bonus uint)
    )
    (let ((collection-id (var-get collection-id-nonce)))
        (asserts! (<= royalty-bonus u500) err-invalid-collection-bonus) ;; Max 5% bonus
        (map-set collections collection-id {
            name: name,
            description: description,
            creator: tx-sender,
            created-at: stacks-block-height,
            artwork-count: u0,
            royalty-bonus: royalty-bonus,
            is-active: true,
        })
        (map-set user-collections tx-sender
            (unwrap-panic (as-max-len?
                (append (default-to (list) (map-get? user-collections tx-sender)) collection-id)
                u20
            ))
        )
        (var-set collection-id-nonce (+ collection-id u1))
        (ok collection-id)
    )
)

(define-public (add-artwork-to-collection
        (token-id uint)
        (collection-id uint)
    )
    (let (
            (collection (unwrap! (map-get? collections collection-id) err-collection-not-found))
            (token-meta (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender (get creator collection)) err-not-collection-creator)
        (asserts! (is-eq tx-sender (get creator token-meta)) err-not-token-owner)
        (asserts! (get is-active collection) err-collection-not-found)
        (asserts! (< (get artwork-count collection) u50) err-collection-full) ;; Max 50 artworks per collection
        (asserts! (is-none (map-get? artwork-collection token-id)) err-artwork-already-in-collection)
        
        (map-set collection-artworks {collection-id: collection-id, token-id: token-id} true)
        (map-set artwork-collection token-id collection-id)
        (map-set collections collection-id
            (merge collection { artwork-count: (+ (get artwork-count collection) u1) })
        )
        (ok true)
    )
)

(define-public (remove-artwork-from-collection (token-id uint))
    (let (
            (collection-id (unwrap! (map-get? artwork-collection token-id) err-collection-not-found))
            (collection (unwrap! (map-get? collections collection-id) err-collection-not-found))
            (token-meta (unwrap! (map-get? token-metadata token-id) err-token-not-found))
        )
        (asserts! (is-eq tx-sender (get creator collection)) err-not-collection-creator)
        (asserts! (is-eq tx-sender (get creator token-meta)) err-not-token-owner)
        
        (map-delete collection-artworks {collection-id: collection-id, token-id: token-id})
        (map-delete artwork-collection token-id)
        (map-set collections collection-id
            (merge collection { artwork-count: (- (get artwork-count collection) u1) })
        )
        (ok true)
    )
)

(define-public (toggle-collection-status (collection-id uint))
    (let ((collection (unwrap! (map-get? collections collection-id) err-collection-not-found)))
        (asserts! (is-eq tx-sender (get creator collection)) err-not-collection-creator)
        (map-set collections collection-id
            (merge collection { is-active: (not (get is-active collection)) })
        )
        (ok (not (get is-active collection)))
    )
)

(define-public (update-collection-info
        (collection-id uint)
        (new-name (string-ascii 64))
        (new-description (string-ascii 256))
    )
    (let ((collection (unwrap! (map-get? collections collection-id) err-collection-not-found)))
        (asserts! (is-eq tx-sender (get creator collection)) err-not-collection-creator)
        (map-set collections collection-id
            (merge collection { 
                name: new-name,
                description: new-description 
            })
        )
        (ok true)
    )
)

;; Enhanced buy function with collection bonus
(define-public (buy-artwork-enhanced (token-id uint))
    (let (
            (listing (unwrap! (map-get? listings token-id) err-listing-not-found))
            (price (get price listing))
            (seller (get seller listing))
            (royalty-info (unwrap! (map-get? token-royalties token-id) err-token-not-found))
            (artist (get artist royalty-info))
            (base-royalty-percentage (get percentage royalty-info))
            (collection-id-opt (map-get? artwork-collection token-id))
            (collection-bonus (match collection-id-opt
                some-collection-id (match (map-get? collections some-collection-id)
                    some-collection (if (get is-active some-collection)
                        (get royalty-bonus some-collection)
                        u0
                    )
                    u0
                )
                u0
            ))
            (total-royalty-percentage (+ base-royalty-percentage collection-bonus))
            (platform-fee (/ (* price (var-get platform-fee-percentage)) u10000))
            (royalty-amount (/ (* price total-royalty-percentage) u10000))
            (seller-amount (- (- price platform-fee) royalty-amount))
        )
        (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
        (try! (as-contract (stx-transfer? royalty-amount tx-sender artist)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender contract-owner)))
        (try! (nft-transfer? digital-art token-id seller tx-sender))
        (unwrap-panic (record-provenance-entry token-id seller tx-sender "enhanced-sale" price))
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

;; Collection Read-Only Functions
(define-read-only (get-collection (collection-id uint))
    (map-get? collections collection-id)
)

(define-read-only (get-user-collections (user principal))
    (default-to (list) (map-get? user-collections user))
)

(define-read-only (get-artwork-collection (token-id uint))
    (map-get? artwork-collection token-id)
)

(define-read-only (is-artwork-in-collection
        (token-id uint)
        (collection-id uint)
    )
    (default-to false (map-get? collection-artworks {collection-id: collection-id, token-id: token-id}))
)

(define-read-only (get-collection-artwork-count (collection-id uint))
    (match (map-get? collections collection-id)
        collection (some (get artwork-count collection))
        none
    )
)

(define-read-only (get-last-collection-id)
    (- (var-get collection-id-nonce) u1)
)

(define-read-only (calculate-enhanced-royalty
        (token-id uint)
        (sale-price uint)
    )
    (let (
            (royalty-info (unwrap! (map-get? token-royalties token-id) err-token-not-found))
            (base-percentage (get percentage royalty-info))
            (collection-id-opt (map-get? artwork-collection token-id))
            (collection-bonus (match collection-id-opt
                some-collection-id (match (map-get? collections some-collection-id)
                    some-collection (if (get is-active some-collection)
                        (get royalty-bonus some-collection)
                        u0
                    )
                    u0
                )
                u0
            ))
            (total-percentage (+ base-percentage collection-bonus))
        )
        (ok {
            base-royalty: (/ (* sale-price base-percentage) u10000),
            collection-bonus: (/ (* sale-price collection-bonus) u10000),
            total-royalty: (/ (* sale-price total-percentage) u10000),
            total-percentage: total-percentage
        })
    )
)

(define-read-only (get-collection-stats (collection-id uint))
    (match (map-get? collections collection-id)
        collection (some {
            collection: collection,
            total-artworks: (get artwork-count collection),
            is-active: (get is-active collection),
            royalty-bonus: (get royalty-bonus collection)
        })
        none
    )
)

(define-public (emergency-withdraw)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (as-contract (stx-transfer? (stx-get-balance tx-sender) tx-sender contract-owner)))
        (ok true)
    )
)
