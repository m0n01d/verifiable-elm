port module Main exposing (main)

{-| The application shell: routing, the live app, the verify harness, and the
ports that back `window.__verify` (idea #5).

Routes:

  - `/` — the real todo app
  - `/verify` — the dashboard (human view of the matrix)
  - `/verify/:unit/:fixture` — one unit mounted in isolation (append
    `?chrome=0` for a clean screenshot)

-}

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, div, p, text)
import Html.Attributes exposing (href, style)
import Json.Encode as E
import Todos
import Url exposing (Url)
import Url.Parser as P exposing ((</>), Parser, oneOf, s, string, top)
import Verify.Encode as Encode
import Verify.Harness as Harness
import Verify.Runner as Runner
import Verify.Specs.TodoApp as TodoAppSpec
import Verify.Specs.TodoStats as TodoStatsSpec



-- PORTS (the window.__verify bridge)


{-| Incoming request: "manifest" | "current" | "runAll".
-}
port verifyRequest : (String -> msg) -> Sub msg


{-| Outgoing answer: `{ kind, data }`.
-}
port verifyResponse : E.Value -> Cmd msg



-- MODEL


type Route
    = AppRoute
    | DashboardRoute
    | UnitRoute String String
    | NotFound


type alias Model =
    { key : Nav.Key
    , url : Url
    , route : Route
    , chrome : Bool
    , todos : Todos.Model
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( applyUrl url
        { key = key
        , url = url
        , route = NotFound
        , chrome = True
        , todos = Todos.empty
        }
    , Cmd.none
    )



-- ROUTING


parser : Parser (Route -> a) a
parser =
    oneOf
        [ P.map AppRoute top
        , P.map UnitRoute (s "verify" </> string </> string)
        , P.map DashboardRoute (s "verify")
        ]


{-| Recompute route + seed the live app when landing on an interactive unit
page. Driving a TodoApp fixture is just folding its steps through update — so
`TodoAppSpec.seed` hands us the post-interaction model to mount.
-}
applyUrl : Url -> Model -> Model
applyUrl url model =
    let
        route =
            Maybe.withDefault NotFound (P.parse parser url)

        chrome =
            url.query
                |> Maybe.map (\q -> not (String.contains "chrome=0" q))
                |> Maybe.withDefault True

        todos =
            case route of
                UnitRoute "TodoApp" fixture ->
                    TodoAppSpec.seed fixture |> Maybe.withDefault model.todos

                _ ->
                    model.todos
    in
    { model | url = url, route = route, chrome = chrome, todos = todos }



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | TodosMsg Todos.Msg
    | VerifyRequest String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External url) ->
            ( model, Nav.load url )

        UrlChanged url ->
            ( applyUrl url model, Cmd.none )

        TodosMsg todoMsg ->
            ( { model | todos = Todos.update todoMsg model.todos }, Cmd.none )

        VerifyRequest kind ->
            ( model, verifyResponse (respond kind model) )


{-| Build the JSON answer for a `window.__verify` request.
-}
respond : String -> Model -> E.Value
respond kind model =
    let
        data =
            case kind of
                "manifest" ->
                    Encode.manifest

                "runAll" ->
                    Encode.results Runner.runAll

                "current" ->
                    case model.route of
                        UnitRoute unit fixture ->
                            Encode.results (List.filterMap identity [ Runner.runOne unit fixture ])

                        _ ->
                            Encode.results Runner.runAll

                _ ->
                    E.null
    in
    E.object [ ( "kind", E.string kind ), ( "data", data ) ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    verifyRequest VerifyRequest



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "Verifiable Elm"
    , body =
        [ if model.chrome then
            nav model.route

          else
            text ""
        , body model
        ]
    }


nav : Route -> Html Msg
nav route =
    div [ style "padding" "8px 16px", style "border-bottom" "1px solid #d1d5db", style "display" "flex", style "gap" "16px" ]
        [ a [ href "/" ] [ text "App" ]
        , a [ href "/verify" ] [ text "Verify dashboard" ]
        , p [ style "margin" "0", style "color" "#6b7280" ]
            [ text ("route: " ++ routeLabel route) ]
        ]


body : Model -> Html Msg
body model =
    case model.route of
        AppRoute ->
            div [ style "padding" "24px", style "max-width" "640px", style "margin" "0 auto" ]
                [ Html.map TodosMsg (Todos.view model.todos) ]

        DashboardRoute ->
            Harness.dashboard

        UnitRoute "TodoApp" fixture ->
            -- Interactive isolation: the real component, mounted in the
            -- fixture's state. Playwright drives this live DOM.
            unitPage "TodoApp" fixture (Html.map TodosMsg (Todos.view model.todos))

        UnitRoute "TodoStats" fixture ->
            -- Static isolation: a display-only unit.
            unitPage "TodoStats" fixture (TodoStatsSpec.renderFixture fixture)

        UnitRoute unit fixture ->
            unitPage unit fixture (p [] [ text "Unknown unit." ])

        NotFound ->
            div [ style "padding" "24px" ]
                [ p [] [ text "Not found. Try " ]
                , a [ href "/verify" ] [ text "/verify" ]
                ]


{-| Render an isolated unit on the left and its declared verification report on
the right — the unit and its proof, side by side (and a tidy screenshot).
-}
unitPage : String -> String -> Html Msg -> Html Msg
unitPage unit fixture mounted =
    div
        [ style "display" "flex"
        , style "flex-wrap" "wrap"
        , style "gap" "24px"
        , style "align-items" "flex-start"
        , style "max-width" "1100px"
        , style "margin" "0 auto"
        , style "padding" "24px"
        ]
        [ div [ style "flex" "1 1 300px", style "min-width" "280px" ]
            [ mounted ]
        , div
            [ style "flex" "2 1 440px"
            , style "min-width" "320px"
            , style "border-left" "1px solid #e5e7eb"
            , style "padding-left" "24px"
            ]
            [ case Runner.runOne unit fixture of
                Just result ->
                    Harness.report result

                Nothing ->
                    text ""
            ]
        ]


routeLabel : Route -> String
routeLabel route =
    case route of
        AppRoute ->
            "/"

        DashboardRoute ->
            "/verify"

        UnitRoute unit fixture ->
            "/verify/" ++ unit ++ "/" ++ fixture

        NotFound ->
            "not found"



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }
