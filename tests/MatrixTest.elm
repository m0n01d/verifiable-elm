module MatrixTest exposing (suite)

{-| The CI path (idea #6): run the whole matrix and assert the verdicts. This is
the same `Runner.runAll` the dashboard and `window.__verify` call — so green
here means green everywhere.
-}

import Expect
import Test exposing (Test, describe, test)
import Verify.Core exposing (Verdict(..), verdictToString)
import Verify.Registry as Registry
import Verify.Runner as Runner


suite : Test
suite =
    describe "verification matrix"
        [ test "every unit has at least one probe fixture (no happy-path-only units)" <|
            \_ ->
                Registry.units
                    |> List.filter (\u -> not (List.any .probe u.fixtures))
                    |> List.map .name
                    |> Expect.equalLists []
        , test "happy-path fixtures pass" <|
            \_ ->
                [ verdictOf "TodoApp" "empty"
                , verdictOf "TodoApp" "three-mixed"
                , verdictOf "TodoApp" "add-one"
                , verdictOf "TodoStats" "balanced"
                , verdictOf "TodoStats" "zero"
                ]
                    |> Expect.equalLists [ "PASS", "PASS", "PASS", "PASS", "PASS" ]
        , test "whitespace-submit probe passes (the no-op held)" <|
            \_ ->
                verdictOf "TodoApp" "whitespace-submit"
                    |> Expect.equal "PASS"
        , test "toggle-all-then-clear probe passes" <|
            \_ ->
                verdictOf "TodoApp" "toggle-all-then-clear"
                    |> Expect.equal "PASS"
        , test "the inconsistent-counts probe is DESIGNED to fail — the harness must catch it" <|
            \_ ->
                verdictOf "TodoStats" "inconsistent-counts"
                    |> Expect.equal "FAIL"
        , test "exactly one fixture fails across the whole matrix" <|
            \_ ->
                Runner.runAll
                    |> List.filter (\r -> verdictToString r.verdict == "FAIL")
                    |> List.map (\r -> r.unit ++ "/" ++ r.fixture)
                    |> Expect.equalLists [ "TodoStats/inconsistent-counts" ]
        ]


verdictOf : String -> String -> String
verdictOf unit fixture =
    Runner.runOne unit fixture
        |> Maybe.map (\r -> verdictToString r.verdict)
        |> Maybe.withDefault "MISSING"
