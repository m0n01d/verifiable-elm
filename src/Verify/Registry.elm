module Verify.Registry exposing (findUnit, units)

{-| The central registry (idea #4): the one list every consumer iterates. Add a
unit here and it shows up in the dashboard, the manifest, `window.__verify`, and
the CI matrix at once.
-}

import Verify.Core exposing (Unit)
import Verify.Specs.TodoApp as TodoApp
import Verify.Specs.TodoStats as TodoStats


units : List Unit
units =
    [ TodoApp.unit
    , TodoStats.unit
    ]


findUnit : String -> Maybe Unit
findUnit name =
    units |> List.filter (\u -> u.name == name) |> List.head
