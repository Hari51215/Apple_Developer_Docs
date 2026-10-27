# CloudKit

Medium article: ["CloudKit from the Sync Engine Down: What CKSyncEngine Still Expects You to Own"](https://hari51215.medium.com/cloudkit-from-the-sync-engine-down-what-cksyncengine-still-expects-you-to-own-c428caeed79b)

No sample app for this topic — CloudKit can't be demonstrated on the free development team used here.
Creating an iCloud container requires an active Apple Developer Program membership with admin
permissions, and every interesting part of the framework sits behind that container: the private and
shared databases need a signed-in iCloud account on a real device, sharing needs two accounts on two
devices to show anything at all, and schema promotion needs CloudKit Console access tied to the paid
membership. A buildable project would be a stack of code that compiles and then fails at runtime with
`missingEntitlement` or `badContainer`, which teaches less than reading the model does. The container
and its three databases, custom zones, `CKRecord` field types and limits, assets and references,
`CKSyncEngine` with its delegate, state serialization and 250-record batches, the `CKOperation` stack
underneath it, query predicate restrictions, subscriptions and server change tokens, `CKShare`
hierarchy and zone-wide sharing, encrypted fields and the keychain-reset recovery path, and the error
codes worth recognising are all covered as code in the article instead.
