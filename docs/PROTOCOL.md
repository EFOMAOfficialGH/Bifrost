# Bifrost protocol

## Version 1

Every endpoint starts with `/bifrost/v1`. JSON uses UTF-8 and field names shown here are part of the protocol. Unknown JSON fields must be ignored so newer clients can talk to older clients.

## Device information

`GET /bifrost/v1/device` returns:

```json
{"protocolVersion":1,"deviceId":"device-123","name":"Bifrost Phone","deviceType":"android","port":43821}
```

The device ID is not a password. Later milestones will add certificate fingerprints and pairing.

## Offer and acceptance

The sender sends a JSON offer to `POST /bifrost/v1/offers`:

```json
{"transferId":"t-123","files":[{"fileId":"f-1","name":"photo.jpg","size":1200,"sha256":"..."}],"totalBytes":1200}
```

A receiver that accepts responds with HTTP `202` and:

```json
{"transferId":"t-123","accepted":true}
```

A receiver that declines responds with HTTP `409` and `accepted:false`.

## Streaming one file

After acceptance, the sender streams bytes with:

```text
PUT /bifrost/v1/transfers/{transferId}/files/{fileId}
Content-Length: <file size>
X-Bifrost-Filename: <display name>
X-Bifrost-SHA256: <lowercase hexadecimal SHA-256>
```

The request body is streamed directly from disk. Neither side loads the whole file into memory. The receiver writes to a temporary file, calculates SHA-256 while writing, and only renames it to the final name after the checksum matches.

A successful file response is HTTP `201` with `{"received":true,"sha256":"..."}`. A mismatch is HTTP `422`; the temporary file is deleted.

## Error codes

`400` means malformed input, `404` means an unknown route or transfer, `409` means declined or conflicting transfer, `413` means a configured size limit was exceeded, and `422` means checksum failure. The body contains a short JSON `error` string safe to show to a user.

## Transport and security boundary

The networking API supports both a plain local HTTP server for deterministic automated tests and an HTTPS server when supplied a Dart `SecurityContext` containing a device certificate and private key. Milestone 2 proves streaming and integrity. Certificate generation, persistence, fingerprint pairing, and refusing untrusted certificates are implemented in the security milestone before real-device release.
