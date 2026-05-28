module Verify.Specs.TodoApp exposing (seed, unit)

{-| The VerifiableUnit for the TodoApp feature (idea #2).

It declares **fixtures** (reproducible models, optionally driven by a list of
`Msg` steps — Elm's pure answer to React's `act()`) and **invariants**
(predicates over the resulting model + surface). The `run` function mounts a
fixture, folds its steps through the real `Todos.update`, then verifies.
-}

import Todos
import Verify.Contract as Contract
import Verify.Core exposing (Check, CheckStatus(..), FixtureMeta, RunResult, Unit, verdictFromChecks)


{-| A fixture: a named starting model plus interaction steps. `probe = True`
flags an adversarial edge case (README idea #2).
-}
type alias Fixture =
    { name : String
    , probe : Bool
    , model : Todos.Model
    , steps : List Todos.Msg
    }


{-| An invariant: a predicate over the driven model and its surface. Returns
`Nothing` when it holds, `Just reason` when it is violated.
-}
type alias Invariant =
    { name : String
    , check : Todos.Model -> Contract.Surface -> Maybe String
    }


fixtures : List Fixture
fixtures =
    [ { name = "empty"
      , probe = False
      , model = Todos.empty
      , steps = []
      }
    , { name = "three-mixed"
      , probe = False
      , model = Todos.withTodos [ ( "Write tests", False ), ( "Ship it", True ), ( "Sleep", False ) ]
      , steps = []
      }
    , { name = "filter-active"
      , probe = False
      , model = Todos.withTodos [ ( "Write tests", False ), ( "Ship it", True ), ( "Sleep", False ) ]
      , steps = [ Todos.SetFilter Todos.Active ]
      }
    , { name = "add-one"
      , probe = False
      , model = Todos.empty
      , steps = [ Todos.DraftChanged "Buy milk", Todos.Submit ]
      }
    , -- Adversarial: drive the real form with whitespace and assert nothing was
      -- added. This is a behavioral probe at the feature surface.
      { name = "whitespace-submit"
      , probe = True
      , model = Todos.empty
      , steps = [ Todos.DraftChanged "    ", Todos.Submit ]
      }
    , -- Adversarial: toggle everything done, then clear. Should leave zero.
      { name = "toggle-all-then-clear"
      , probe = True
      , model = Todos.withTodos [ ( "a", False ), ( "b", False ) ]
      , steps = [ Todos.Toggle 1, Todos.Toggle 2, Todos.ClearCompleted ]
      }
    ]


invariants : List Invariant
invariants =
    [ { name = "counts-add-up"
      , check =
            \model _ ->
                let
                    total =
                        List.length model.todos

                    done =
                        Todos.countDone model.todos

                    active =
                        Todos.countActive model.todos
                in
                if done + active == total then
                    Nothing

                else
                    Just
                        ("done ("
                            ++ String.fromInt done
                            ++ ") + active ("
                            ++ String.fromInt active
                            ++ ") /= total ("
                            ++ String.fromInt total
                            ++ ")"
                        )
      }
    , { name = "no-blank-todos"
      , check =
            \model _ ->
                if List.any (\t -> String.trim t.text == "") model.todos then
                    Just "a todo has blank text — whitespace submit must be a no-op"

                else
                    Nothing
      }
    , { name = "surface-matches-model"
      , check =
            \model surface ->
                let
                    expected =
                        String.fromInt (List.length model.todos)

                    reported =
                        surface
                            |> List.filter (\( k, _ ) -> k == "total")
                            |> List.head
                            |> Maybe.map Tuple.second
                            |> Maybe.withDefault "<missing>"
                in
                if expected == reported then
                    Nothing

                else
                    Just ("surface total " ++ reported ++ " /= model total " ++ expected)
      }
    ]



-- ERASED UNIT (idea #2/#4)


unit : Unit
unit =
    { name = "TodoApp"
    , fixtures = List.map (\f -> FixtureMeta f.name f.probe) fixtures
    , run = run
    }


{-| Resolve a fixture to its post-interaction model (for the isolated,
interactive `/verify/TodoApp/:fixture` route in Main).
-}
seed : String -> Maybe Todos.Model
seed name =
    find name |> Maybe.map drive


find : String -> Maybe Fixture
find name =
    fixtures |> List.filter (\f -> f.name == name) |> List.head


drive : Fixture -> Todos.Model
drive fixture =
    List.foldl Todos.update fixture.model fixture.steps


run : String -> RunResult
run name =
    case find name of
        Nothing ->
            { unit = "TodoApp"
            , fixture = name
            , probe = False
            , verdict = Verify.Core.Blocked ("no such fixture: " ++ name)
            , checks = []
            , surface = []
            }

        Just fixture ->
            let
                model =
                    drive fixture

                surface =
                    Todos.surface model

                invariantChecks =
                    List.map (toCheck model surface) invariants

                checks =
                    invariantChecks ++ Contract.surfaceContractChecks surface
            in
            { unit = "TodoApp"
            , fixture = name
            , probe = fixture.probe
            , verdict = verdictFromChecks checks
            , checks = checks
            , surface = surface
            }


toCheck : Todos.Model -> Contract.Surface -> Invariant -> Check
toCheck model surface invariant =
    case invariant.check model surface of
        Nothing ->
            { verifier = "invariants"
            , name = invariant.name
            , status = Ok_
            , detail = "holds"
            }

        Just reason ->
            { verifier = "invariants"
            , name = invariant.name
            , status = FailC
            , detail = reason
            }
