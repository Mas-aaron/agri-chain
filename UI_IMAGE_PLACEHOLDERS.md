# UI Image Placeholders (AgriChain)

This project currently uses **network image placeholders** (Picsum) to achieve a modern photo-based UI.

When you have final branding/photos, replace these URLs with:

- Local assets under `agri-chain/assets/images/` (recommended for offline)
- Or Huawei OBS object URLs (recommended for cloud-managed content)

## Current placeholder URLs

- Dashboard header
  - `https://picsum.photos/seed/agrichain_dashboard/1200/700`

- Scan (leaf diagnosis) header
  - `https://picsum.photos/seed/agrichain_scan/1200/700`

- Yield forecast header
  - `https://picsum.photos/seed/agrichain_yield/1200/700`

- Fields header
  - `https://picsum.photos/seed/agrichain_fields/1200/700`

- Alerts header
  - `https://picsum.photos/seed/agrichain_alerts/1200/700`

- Settings header
  - `https://picsum.photos/seed/agrichain_settings/1200/700`

- Market (Blockchain hub) header
  - `https://picsum.photos/seed/agrichain_market/1200/700`

- Market cards
  - Contracts card image
    - `https://picsum.photos/seed/agrichain_contracts/400/400`
  - Ledger card image
    - `https://picsum.photos/seed/agrichain_ledger/400/400`

- Contracts screen header
  - `https://picsum.photos/seed/agrichain_contracts_header/1200/700`

- Ledger screen header
  - `https://picsum.photos/seed/agrichain_ledger_header/1200/700`

- Field list item images
  - `https://picsum.photos/seed/field_<fieldId>/300/300`

## Recommended future asset filenames

If you want to switch to local assets, add these files under `agri-chain/assets/images/`:

- `header_dashboard.jpg`
- `header_scan.jpg`
- `header_yield.jpg`
- `header_fields.jpg`
- `header_alerts.jpg`
- `header_settings.jpg`
- `header_market.jpg`
- `header_contracts.jpg`
- `header_ledger.jpg`

Then replace the URLs in the screens with `Image.asset(...)`.
