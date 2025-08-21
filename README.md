# 🎨 Digital Art Royalties Smart Contract

A Clarity smart contract for managing digital art NFTs with automatic royalty distribution on the Stacks blockchain.

## 🌟 Features

- 🖼️ **NFT Minting**: Create unique digital art tokens with metadata
- 💰 **Royalty System**: Automatic royalty payments to original artists
- 🏪 **Marketplace**: Built-in listing and buying functionality
- 🎯 **Batch Operations**: Mint multiple artworks at once
- 📊 **Analytics**: Track earnings and transaction history
- 🔒 **Secure Transfers**: Protected ownership transfers

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity and Stacks

### Installation

```bash
git clone <repository-url>
cd Digital-Art-Royalties
clarinet check
```

## 📋 Contract Functions

### 🎭 Minting Functions

#### `mint-artwork`
Create a new digital art NFT with royalty settings.

```clarity
(mint-artwork "Sunset Dreams" "A beautiful digital sunset" "https://example.com/image.jpg" u500)
```

- `name`: Artwork title (max 64 characters)
- `description`: Artwork description (max 256 characters) 
- `image-uri`: Image URL (max 256 characters)
- `royalty-percentage`: Royalty percentage in basis points (500 = 5%)

#### `batch-mint`
Mint up to 10 artworks in a single transaction.

### 🛒 Marketplace Functions

#### `list-artwork`
List an artwork for sale.

```clarity
(list-artwork u1 u1000000)
```

- `token-id`: The artwork ID
- `price`: Sale price in microSTX

#### `buy-artwork`
Purchase a listed artwork with automatic royalty distribution.

```clarity
(buy-artwork u1)
```

#### `unlist-artwork`
Remove artwork from marketplace.

### 🔄 Transfer Functions

#### `transfer-artwork`
Transfer artwork to another user.

```clarity
(transfer-artwork u1 'SP1... 'SP2...)
```

### ⚙️ Admin Functions

#### `set-platform-fee`
Update platform fee (owner only).

#### `update-royalty-percentage`
Update artwork royalty percentage (creator only).

## 📖 Read-Only Functions

- `get-token-metadata`: Get artwork metadata
- `get-token-royalty-info`: Get royalty information
- `get-listing`: Get marketplace listing details
- `get-user-balance`: Get user's earned balance
- `get-artwork-history`: Get complete artwork history
- `calculate-royalty-amount`: Calculate royalty for a sale price
- `is-artwork-listed`: Check if artwork is listed

## 💡 Usage Examples

### Creating and Selling Art

```clarity
;; 1. Mint new artwork
(contract-call? .digital-art-royalties mint-artwork 
  "Digital Landscape" 
  "A serene digital landscape painting" 
  "https://mysite.com/art1.jpg" 
  u750)

;; 2. List for sale  
(contract-call? .digital-art-royalties list-artwork u1 u5000000)

;; 3. Buy artwork (as different user)
(contract-call? .digital-art-royalties buy-artwork u1)
```

### Checking Information

```clarity
;; Get artwork details
(contract-call? .digital-art-royalties get-token-metadata u1)

;; Check if listed
(contract-call? .digital-art-royalties is-artwork-listed u1)

;; Get artist earnings
(contract-call? .digital-art-royalties get-user-balance 'SP1...)
```

## 🎯 Royalty System

- **Royalty Range**: 0-10% (0-1000 basis points)
- **Platform Fee**: 2.5% (configurable by owner)
- **Distribution**: Automatic on each sale
  - Artist receives their royalty percentage
  - Platform receives platform fee
  - Seller receives remaining amount

## 🔐 Security Features

- Owner-only administrative functions
- Creator-only royalty updates
- Secure NFT transfers
- Input validation on all functions
- Emergency withdrawal for contract owner

## 📊 Contract Data

### Maps
- `token-metadata`: Stores artwork information
- `token-royalties`: Tracks royalty settings and earnings
- `listings`: Active marketplace listings
- `user-balances`: User earnings tracking

### Variables
- `token-id-nonce`: Next token ID counter
- `platform-fee-percentage`: Platform fee (250 = 2.5%)

## 🧪 Testing

Run the test suite:

```bash
npm install
npm test
```

## 📄 License

This project is licensed under the MIT License.

---

*Built with ❤️ on Stacks blockchain*
