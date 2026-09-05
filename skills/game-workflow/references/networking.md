# Version-aware networking contracts

Confirm installed product/package and version, topology (such as listen server or dedicated/headless), expected scale and source evidence. Consult official documentation/API for that version before prescribing framework calls. If version is unavailable, provide conceptual advice and label the unresolved API mapping.

Map concepts to the verified stack, checking names and constraints: Photon Fusion state/RPC/input-prediction/interest; FishNet SyncTypes and RPC/Observers/prediction; Mirror SyncVar/SyncCollections, Command, ClientRpc/TargetRpc, NetworkMessage and interest management. These are discovery terms, not assumed version-compatible prescriptions.

Define authoritative state and validated client intent. Separate durable replicated state required by late join from transient network messages and local domain events. For each relevant contract identify sender/receiver authority, serialization/schema version, reliability/ordering, deduplication/idempotency, tick/send/render rate, observer scope, and behavior under replay/resimulation. Never assume a transient RPC reconstructs persistent state.

Consider latency, jitter, loss, reorder, duplicates, MTU/fragmentation, congestion/backpressure and security for the actual problem. Specify prediction/reconciliation and interpolation where supported and needed, with bounded history and late-join behavior. Keep host-local conveniences out of dedicated-server contracts. Define connect/disconnect, timeout, retry/backoff, heartbeat, reconnect and cleanup ownership.

Estimate bandwidth by direction and message class:
`(payload + protocol/transport/encryption overhead) × send rate × observers`.
Account for relevant acknowledgments/retransmits/fragmentation. Memory includes snapshot/history size × entities × retained ticks, plus queues, serialization copies, prediction/rewind state and GC allocations. Bound each lifetime and queue.

Measure under stated players/entities, tick/send rates, topology/device, capture duration and simulated network conditions. Use average, p95 and peak when assessing load; do not declare success from an average alone. Label provisional budgets and estimates separately from captures. Avoid an expensive performance campaign for a change with no performance risk.

Hand off domain/save ownership to the game architect, protocol/authority decisions to the network advisor, implementation to the stack lead, and observable scenarios to the tester. Escalate conflicting contracts with evidence instead of silently replacing another owner's decision.
