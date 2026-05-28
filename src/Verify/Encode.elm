module Verify.Encode exposing (manifest, results)

{-| Idea #5: the JSON the agent handle (`window.__verify`) returns. The
dashboard and the agent see the same data — this module is the single encoder
both rely on.
-}

import Json.Encode as E
import Verify.Core exposing (Check, RunResult, Verdict(..), checkStatusToString, verdictToString)
import Verify.Registry as Registry


{-| `window.__verify.manifest()` — every unit × fixture × verifier.
-}
manifest : E.Value
manifest =
    E.object
        [ ( "version", E.int 1 )
        , ( "units"
          , E.list encodeUnitManifest Registry.units
          )
        ]


encodeUnitManifest : Verify.Core.Unit -> E.Value
encodeUnitManifest unit =
    E.object
        [ ( "name", E.string unit.name )
        , ( "verifiers", E.list E.string [ "invariants", "dom-contract" ] )
        , ( "fixtures"
          , E.list
                (\f ->
                    E.object
                        [ ( "name", E.string f.name )
                        , ( "probe", E.bool f.probe )
                        , ( "route", E.string ("/verify/" ++ unit.name ++ "/" ++ f.name) )
                        ]
                )
                unit.fixtures
          )
        ]


{-| Encode a list of run results (`runAll()` / `current()`).
-}
results : List RunResult -> E.Value
results rs =
    E.list encodeResult rs


encodeResult : RunResult -> E.Value
encodeResult r =
    E.object
        [ ( "unit", E.string r.unit )
        , ( "fixture", E.string r.fixture )
        , ( "probe", E.bool r.probe )
        , ( "verdict", E.string (verdictToString r.verdict) )
        , ( "reason", E.string (verdictReason r.verdict) )
        , ( "checks", E.list encodeCheck r.checks )
        , ( "surface"
          , E.object (List.map (\( k, v ) -> ( k, E.string v )) r.surface)
          )
        ]


encodeCheck : Check -> E.Value
encodeCheck c =
    E.object
        [ ( "verifier", E.string c.verifier )
        , ( "name", E.string c.name )
        , ( "status", E.string (checkStatusToString c.status) )
        , ( "detail", E.string c.detail )
        ]


verdictReason : Verdict -> String
verdictReason verdict =
    case verdict of
        Pass ->
            ""

        Fail reason ->
            reason

        Blocked reason ->
            reason

        Skip reason ->
            reason
