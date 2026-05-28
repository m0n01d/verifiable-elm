module Verify.Runner exposing (runAll, runOne)

{-| mount → drive → verify → verdict (idea #6). One code path; the dashboard,
`window.__verify`, and the CI matrix all call it.
-}

import Verify.Core exposing (RunResult)
import Verify.Registry as Registry


{-| Run every unit × fixture. This is the full verification matrix.
-}
runAll : List RunResult
runAll =
    Registry.units
        |> List.concatMap (\unit -> List.map (\f -> unit.run f.name) unit.fixtures)


{-| Run a single unit × fixture (what the isolated `/verify/:unit/:fixture`
route reports).
-}
runOne : String -> String -> Maybe RunResult
runOne unitName fixtureName =
    Registry.findUnit unitName
        |> Maybe.map (\unit -> unit.run fixtureName)
