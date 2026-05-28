module Verify.Specs.TodoStats exposing (renderFixture, unit)

{-| The VerifiableUnit for the TodoStats display component.

This unit hosts the **probe that is designed to fail**: the
`inconsistent-counts` fixture feeds a model whose counts don't add up, so the
`counts-add-up` invariant fails. That FAIL is the point — it proves the harness
catches lies, not just confirms truths.
-}

import Html exposing (Html)
import TodoStats
import Verify.Contract as Contract
import Verify.Core exposing (Check, CheckStatus(..), FixtureMeta, RunResult, Unit, verdictFromChecks)


type alias Fixture =
    { name : String
    , probe : Bool
    , model : TodoStats.Model
    }


type alias Invariant =
    { name : String
    , check : TodoStats.Model -> Maybe String
    }


fixtures : List Fixture
fixtures =
    [ { name = "balanced"
      , probe = False
      , model = { total = 3, done = 1, active = 2 }
      }
    , { name = "zero"
      , probe = False
      , model = { total = 0, done = 0, active = 0 }
      }
    , -- DESIGNED TO FAIL: 2 + 2 /= 3. The runner must report FAIL here.
      { name = "inconsistent-counts"
      , probe = True
      , model = { total = 3, done = 2, active = 2 }
      }
    ]


invariants : List Invariant
invariants =
    [ { name = "counts-add-up"
      , check =
            \m ->
                if m.done + m.active == m.total then
                    Nothing

                else
                    Just
                        ("done ("
                            ++ String.fromInt m.done
                            ++ ") + active ("
                            ++ String.fromInt m.active
                            ++ ") /= total ("
                            ++ String.fromInt m.total
                            ++ ")"
                        )
      }
    , { name = "non-negative"
      , check =
            \m ->
                if m.total >= 0 && m.done >= 0 && m.active >= 0 then
                    Nothing

                else
                    Just "a count is negative"
      }
    ]


unit : Unit
unit =
    { name = "TodoStats"
    , fixtures = List.map (\f -> FixtureMeta f.name f.probe) fixtures
    , run = run
    }


renderFixture : String -> Html msg
renderFixture name =
    case find name of
        Just fixture ->
            TodoStats.view fixture.model

        Nothing ->
            Html.text ("no such fixture: " ++ name)


find : String -> Maybe Fixture
find name =
    fixtures |> List.filter (\f -> f.name == name) |> List.head


run : String -> RunResult
run name =
    case find name of
        Nothing ->
            { unit = "TodoStats"
            , fixture = name
            , probe = False
            , verdict = Verify.Core.Blocked ("no such fixture: " ++ name)
            , checks = []
            , surface = []
            }

        Just fixture ->
            let
                surface =
                    TodoStats.surface fixture.model

                invariantChecks =
                    List.map (toCheck fixture.model) invariants

                checks =
                    invariantChecks ++ Contract.surfaceContractChecks surface
            in
            { unit = "TodoStats"
            , fixture = name
            , probe = fixture.probe
            , verdict = verdictFromChecks checks
            , checks = checks
            , surface = surface
            }


toCheck : TodoStats.Model -> Invariant -> Check
toCheck model invariant =
    case invariant.check model of
        Nothing ->
            { verifier = "invariants", name = invariant.name, status = Ok_, detail = "holds" }

        Just reason ->
            { verifier = "invariants", name = invariant.name, status = FailC, detail = reason }
