module Verify.Harness exposing (dashboard, report)

{-| The human rendering of the same data the agent reads (idea #5). The
dashboard at `/verify` is just a view over `Runner.runAll`; the report is the
view over a single `RunResult`.
-}

import Html exposing (Html, a, code, div, h1, h2, h3, p, span, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (class, href, style)
import Verify.Core exposing (Check, RunResult, Verdict(..), checkStatusToString, verdictToString)
import Verify.Runner as Runner



-- DASHBOARD: /verify


dashboard : Html msg
dashboard =
    let
        rs =
            Runner.runAll

        passes =
            List.length (List.filter (\r -> r.verdict == Pass) rs)

        fails =
            List.length (List.filter (isFail << .verdict) rs)
    in
    div [ style "padding" "24px", style "max-width" "900px", style "margin" "0 auto" ]
        [ h1 [] [ text "Verification dashboard" ]
        , p []
            [ text "The full unit × fixture matrix. This is exactly what "
            , code [] [ text "window.__verify.runAll()" ]
            , text " returns — agent and human read the same truth."
            ]
        , p []
            [ verdictBadge Pass
            , text (" " ++ String.fromInt passes ++ " pass   ")
            , verdictBadge (Fail "")
            , text (" " ++ String.fromInt fails ++ " fail")
            , text "  (one FAIL is the inconsistent-counts probe — designed to fail)"
            ]
        , table []
            [ thead []
                [ tr []
                    [ th [] [ text "Unit" ]
                    , th [] [ text "Fixture" ]
                    , th [] [ text "Probe" ]
                    , th [] [ text "Verdict" ]
                    , th [] [ text "Isolated route" ]
                    ]
                ]
            , tbody [] (List.map row rs)
            ]
        ]


row : RunResult -> Html msg
row r =
    let
        route =
            "/verify/" ++ r.unit ++ "/" ++ r.fixture
    in
    tr []
        [ td [] [ code [] [ text r.unit ] ]
        , td [] [ text r.fixture ]
        , td []
            [ text
                (if r.probe then
                    "🔍"

                 else
                    ""
                )
            ]
        , td [] [ verdictBadge r.verdict ]
        , td [] [ a [ href route ] [ text route ] ]
        ]



-- REPORT: /verify/:unit/:fixture


report : RunResult -> Html msg
report r =
    div []
        [ h2 [ style "margin-top" "0" ]
            [ text (r.unit ++ " / " ++ r.fixture ++ " ")
            , verdictBadge r.verdict
            ]
        , case verdictReason r.verdict of
            "" ->
                text ""

            reason ->
                p [ class "verdict-FAIL" ] [ text reason ]
        , h3 [] [ text "Surface (data-verify-*)" ]
        , surfaceTable r.surface
        , h3 [] [ text "Checks" ]
        , checksTable r.checks
        ]


surfaceTable : List ( String, String ) -> Html msg
surfaceTable pairs =
    table []
        [ tbody []
            (List.map
                (\( k, v ) ->
                    tr []
                        [ td [] [ code [] [ text ("data-verify-" ++ k) ] ]
                        , td [] [ text v ]
                        ]
                )
                pairs
            )
        ]


checksTable : List Check -> Html msg
checksTable checks =
    table []
        [ thead []
            [ tr []
                [ th [] [ text "Verifier" ]
                , th [] [ text "Check" ]
                , th [] [ text "Status" ]
                , th [] [ text "Detail" ]
                ]
            ]
        , tbody []
            (List.map
                (\c ->
                    tr []
                        [ td [] [ code [] [ text c.verifier ] ]
                        , td [] [ text c.name ]
                        , td [] [ text (checkIcon c.status ++ " " ++ checkStatusToString c.status) ]
                        , td [] [ text c.detail ]
                        ]
                )
                checks
            )
        ]



-- SHARED


verdictBadge : Verdict -> Html msg
verdictBadge verdict =
    span [ class ("verdict-" ++ verdictToString verdict), style "font-weight" "700" ]
        [ text (verdictToString verdict) ]


isFail : Verdict -> Bool
isFail verdict =
    case verdict of
        Fail _ ->
            True

        _ ->
            False


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


checkIcon : Verify.Core.CheckStatus -> String
checkIcon status =
    case status of
        Verify.Core.Ok_ ->
            "✅"

        Verify.Core.FailC ->
            "❌"

        Verify.Core.Warn ->
            "⚠️"

        Verify.Core.Probe ->
            "🔍"
