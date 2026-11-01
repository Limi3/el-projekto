# Contract Requests

Back to [[POP PARADE]]

What B (Limi's side) needs A (Saud's side) to define or confirm before integration. The full list is in [[CONTRACT_REQUESTS]] (`pop-parade/docs/b/CONTRACT_REQUESTS.md`).

Top items:
1. Rojo paths for B's folders (`ReplicatedStorage.PopParade.Content`, `ServerScriptService.PopParadeWorld`, `StarterPlayerScripts.PopParadeClient`)
2. Call `WorldBuilder.Build` once in A's server bootstrap and register the manifest
3. Confirm the WorldUpdate snapshot shape, pop/inflate generation meaning, and event payloads
4. Action payloads + ClientState fields the UI reads (incl. `offers[].productId` for live prices)
5. A client-readable balance accessor (costs/values for the upgrade screen)
6. Player attributes `PopParade_NeedleSkin/_Trail/_Wings` so everyone sees each other's cosmetics

Start here for the whole handoff: [[HANDOFF]].
