# Backup format, version 1

A backup is a folder of plain files, so it can be read without the app and restored into a newer
one. The code is `BackupBundle` in `Packages/Core/Storage` (#56). iCloud Drive backup (#57) writes
this folder; the merging restore (#58) reads it.

```
Asvada backup/
├── manifest.json
├── data.json
└── photos/
    ├── <photo id>.photo
    └── <photo id>.thumb
```

## `manifest.json`

| Key | Meaning |
|---|---|
| `formatVersion` | The bundle format, an integer. This document describes 1. A reader refuses a bundle with a higher number than it knows. |
| `schemaVersion` | The store schema the rows were written from, e.g. `"1.0.0"` (`CurrentSchema`). |
| `createdAt` | When the backup was made (a date, see below). |
| `counts` | Rows in `data.json`: `collections`, `items`, `entries`, `photos`, `trips`, `tags`, `people`. |
| `files` | The SHA-256 of every other file in the bundle (lowercase hex), keyed by its path. |

Before anything is restored the reader checks that the format is one it knows, that every file in
`files` is present and matches its checksum, and that `counts` match `data.json`. A bundle that fails
any check changes nothing.

## `data.json`

One flat table per kind of row, linked by ids (UUIDs):

- `collections`: `id`, `name`, `icon`, `accentName`, `kind`, `ratingMode`, `defaultView`,
  `itemSource`, `fieldSchemaJSON`, `sortIndex`, `isHidden`, `createdAt`
- `items`: `id`, `name`, `externalRef`, `latitude`, `longitude`, `countryCode`, `metadataJSON`,
  `rankScore`, `createdAt`, `collectionID`
- `entries`: `id`, `date`, `rating`, `notes`, `extraJSON`, `itemID`, `tripID`, `tagIDs`, `personIDs`
- `photos`: `id`, `takenAt`, `latitude`, `longitude`, `entryID`, `imageFile`, `thumbnailFile`
- `trips`: `id`, `name`, `start`, `end`
- `tags` and `people`: `id`, `name`

Notes:

- **Dates** are numbers: seconds since 1 January 2001 UTC (Apple's reference date), as a decimal.
  That keeps every bit of the original `Date`, so a restore is exact.
- **`Data` values** (`fieldSchemaJSON`, `metadataJSON`, `extraJSON`) are base64 strings.
- **Enums** (`kind`, `ratingMode`, `defaultView`, `itemSource`) are their raw strings. A value the
  reader doesn't know falls back to a default (`custom`, `stars`, `list`, `manual`) instead of
  failing the restore.
- **Optional links** (`collectionID`, `itemID`, `tripID`, `entryID`) can be absent: the row is
  restored without that link.
- **Keys are sorted and rows are ordered by id**, so exporting the same store twice gives the same
  bytes (apart from `createdAt` in the manifest).

## `photos/`

Each photo's pictures, exactly as the app holds them (HEIC or JPEG), named for the photo's id:
`<id>.photo` is the downscaled copy and `<id>.thumb` the thumbnail. A photo record names its files in
`imageFile` and `thumbnailFile` (paths relative to the bundle); a photo with no such copy leaves the
key out.

## Restoring

`BackupBundle.importFiles` adds every row whose id isn't in the store yet, then links the new rows,
and saves. A row whose id is already there is left as it is, so restoring the same backup twice adds
nothing. Choosing between two different versions of a row is the merging restore's job (#58).

## Changing the format

- Adding a key a reader can ignore doesn't need a new `formatVersion`; readers must ignore keys
  they don't know.
- Changing what a key means, or removing one, bumps `formatVersion`. Keep reading older versions.
- A store schema change (`SchemaV2`) updates `schemaVersion`, and the reader maps older rows
  forward.
