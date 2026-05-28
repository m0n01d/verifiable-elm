module Verify.Core exposing
    ( Check
    , CheckStatus(..)
    , FixtureMeta
    , RunResult
    , Unit
    , Verdict(..)
    , checkStatusToString
    , verdictFromChecks
    , verdictToString
    )

{-| Idea #6: one verdict taxonomy, three consumers (dashboard, agent, CI).

These types are deliberately tiny and string-encodable so the exact same values
flow through `elm-test`, the `/verify` dashboard, and `window.__verify`.
-}


{-| The outcome of running one fixture.

`Blocked` (couldn't observe) is deliberately distinct from `Fail` (observed and
wrong). When in doubt, the runner fails: a false PASS ships bugs, a false FAIL
costs one more look.

-}
type Verdict
    = Pass
    | Fail String
    | Blocked String
    | Skip String


{-| A single check produced by a verifier.

`Probe` marks a check that comes from an adversarial fixture — it is expected to
surface something interesting, not necessarily to pass.

-}
type CheckStatus
    = Ok_
    | FailC
    | Warn
    | Probe


type alias Check =
    { verifier : String
    , name : String
    , status : CheckStatus
    , detail : String
    }


{-| What the dashboard and manifest list for each fixture. `probe = True` marks
an adversarial edge case (see idea #2).
-}
type alias FixtureMeta =
    { name : String
    , probe : Bool
    }


{-| The structured result of one unit × fixture run.
-}
type alias RunResult =
    { unit : String
    , fixture : String
    , probe : Bool
    , verdict : Verdict
    , checks : List Check
    , surface : List ( String, String )
    }


{-| Idea #2/#4: a unit is type-erased behind two functions so units with
different model types can live in one registry. `run` mounts a fixture, drives
it, verifies it, and returns a structured result.
-}
type alias Unit =
    { name : String
    , fixtures : List FixtureMeta
    , run : String -> RunResult
    }


{-| Roll a list of checks up into one verdict. Any failing check fails the
fixture; an unrunnable check blocks it; otherwise it passes.
-}
verdictFromChecks : List Check -> Verdict
verdictFromChecks checks =
    if List.any (\c -> c.status == FailC) checks then
        Fail (summarize FailC checks)

    else if List.isEmpty checks then
        Blocked "no checks ran"

    else
        Pass


summarize : CheckStatus -> List Check -> String
summarize status checks =
    checks
        |> List.filter (\c -> c.status == status)
        |> List.map (\c -> c.verifier ++ "/" ++ c.name)
        |> String.join ", "


verdictToString : Verdict -> String
verdictToString verdict =
    case verdict of
        Pass ->
            "PASS"

        Fail _ ->
            "FAIL"

        Blocked _ ->
            "BLOCKED"

        Skip _ ->
            "SKIP"


checkStatusToString : CheckStatus -> String
checkStatusToString status =
    case status of
        Ok_ ->
            "ok"

        FailC ->
            "fail"

        Warn ->
            "warn"

        Probe ->
            "probe"
