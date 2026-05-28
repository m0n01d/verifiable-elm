module TodoStats exposing (Model, surface, view)

{-| A tiny display-only unit: it renders three counts. It exists to host the
**probe that is designed to fail** (idea, README "Things deliberately
demonstrated"): a fixture where the counts don't add up, proving the framework
catches lies rather than only confirming truths.

Note there is no `update` — the surface comes straight from the model, so a
broken fixture model is the only way to produce a broken surface.

-}

import Html exposing (Html, dd, div, dl, dt, section, text)
import Html.Attributes exposing (attribute, class)
import Verify.Contract exposing (Surface, verifyAttrs)


type alias Model =
    { total : Int
    , done : Int
    , active : Int
    }


surface : Model -> Surface
surface model =
    [ ( "unit", "TodoStats" )
    , ( "total", String.fromInt model.total )
    , ( "done", String.fromInt model.done )
    , ( "active", String.fromInt model.active )
    ]


view : Model -> Html msg
view model =
    section
        (verifyAttrs (surface model) ++ [ class "todo-stats", attribute "aria-label" "Todo statistics" ])
        [ dl []
            [ stat "Total" model.total
            , stat "Done" model.done
            , stat "Active" model.active
            ]
        ]


stat : String -> Int -> Html msg
stat name n =
    div [ class "stat" ]
        [ dt [] [ text name ]
        , dd [] [ text (String.fromInt n) ]
        ]
