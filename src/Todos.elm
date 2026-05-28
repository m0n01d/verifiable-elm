module Todos exposing
    ( Filter(..)
    , Model
    , Msg(..)
    , Todo
    , countActive
    , countDone
    , empty
    , filterToString
    , surface
    , update
    , view
    , withTodos
    )

{-| The actual app. The only thing it does for verification is emit its state
as a `data-verify-*` surface (idea #1). Everything else is a normal Elm
component: a pure `update` and a `view`.
-}

import Html exposing (Html, button, div, h1, input, label, li, section, span, text, ul)
import Html.Attributes exposing (attribute, checked, class, disabled, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Verify.Contract exposing (Surface, verifyAttrs)



-- MODEL


type alias Todo =
    { id : Int
    , text : String
    , done : Bool
    }


type Filter
    = All
    | Active
    | Completed


type alias Model =
    { todos : List Todo
    , draft : String
    , filter : Filter
    , nextId : Int
    }


empty : Model
empty =
    { todos = [], draft = "", filter = All, nextId = 1 }


{-| Seed a model from a list of `(text, done)` pairs — used by fixtures.
-}
withTodos : List ( String, Bool ) -> Model
withTodos pairs =
    let
        toTodo index ( txt, done ) =
            { id = index + 1, text = txt, done = done }
    in
    { empty
        | todos = List.indexedMap toTodo pairs
        , nextId = List.length pairs + 1
    }



-- DERIVED STATE


countDone : List Todo -> Int
countDone =
    List.filter .done >> List.length


countActive : List Todo -> Int
countActive =
    List.filter (not << .done) >> List.length


filterToString : Filter -> String
filterToString filter =
    case filter of
        All ->
            "all"

        Active ->
            "active"

        Completed ->
            "completed"


visible : Model -> List Todo
visible model =
    case model.filter of
        All ->
            model.todos

        Active ->
            List.filter (not << .done) model.todos

        Completed ->
            List.filter .done model.todos



-- THE SURFACE (idea #1): single source of truth for data-verify-*.


surface : Model -> Surface
surface model =
    [ ( "unit", "TodoApp" )
    , ( "total", String.fromInt (List.length model.todos) )
    , ( "done", String.fromInt (countDone model.todos) )
    , ( "active", String.fromInt (countActive model.todos) )
    , ( "visible", String.fromInt (List.length (visible model)) )
    , ( "filter", filterToString model.filter )
    ]



-- UPDATE


type Msg
    = DraftChanged String
    | Submit
    | Toggle Int
    | Delete Int
    | SetFilter Filter
    | ClearCompleted


update : Msg -> Model -> Model
update msg model =
    case msg of
        DraftChanged draft ->
            { model | draft = draft }

        Submit ->
            let
                trimmed =
                    String.trim model.draft
            in
            if String.isEmpty trimmed then
                -- Whitespace-only submit is a no-op. The whitespace-submit
                -- probe asserts this at the real DOM surface.
                { model | draft = "" }

            else
                { model
                    | todos = model.todos ++ [ { id = model.nextId, text = trimmed, done = False } ]
                    , draft = ""
                    , nextId = model.nextId + 1
                }

        Toggle id ->
            { model
                | todos =
                    List.map
                        (\t ->
                            if t.id == id then
                                { t | done = not t.done }

                            else
                                t
                        )
                        model.todos
            }

        Delete id ->
            { model | todos = List.filter (\t -> t.id /= id) model.todos }

        SetFilter filter ->
            { model | filter = filter }

        ClearCompleted ->
            { model | todos = List.filter (not << .done) model.todos }



-- VIEW


view : Model -> Html Msg
view model =
    section
        (verifyAttrs (surface model) ++ [ class "todo-app", attribute "aria-label" "Todo application" ])
        [ h1 [] [ text "Todos" ]
        , Html.form [ onSubmit Submit, class "add-form" ]
            [ label []
                [ span [ class "sr-only" ] [ text "New todo" ]
                , input
                    [ type_ "text"
                    , placeholder "What needs doing?"
                    , value model.draft
                    , onInput DraftChanged
                    , attribute "aria-label" "New todo"
                    ]
                    []
                ]
            , button [ type_ "submit" ] [ text "Add" ]
            ]
        , filterBar model.filter
        , ul [ class "todo-list" ] (List.map todoItem (visible model))
        , footer model
        ]


filterBar : Filter -> Html Msg
filterBar active =
    let
        item filter txt =
            button
                [ onClick (SetFilter filter)
                , disabled (filter == active)
                , attribute "aria-pressed"
                    (if filter == active then
                        "true"

                     else
                        "false"
                    )
                ]
                [ text txt ]
    in
    div [ class "filters", attribute "role" "group", attribute "aria-label" "Filter todos" ]
        [ item All "All"
        , item Active "Active"
        , item Completed "Completed"
        ]


todoItem : Todo -> Html Msg
todoItem todo =
    li
        [ class "todo-item"
        , attribute "data-verify-unit" "TodoItem"
        , attribute "data-verify-id" (String.fromInt todo.id)
        , attribute "data-verify-done"
            (if todo.done then
                "true"

             else
                "false"
            )
        ]
        [ label []
            [ input
                [ type_ "checkbox"
                , checked todo.done
                , onClick (Toggle todo.id)
                , attribute "aria-label" ("Toggle " ++ todo.text)
                ]
                []
            , span [ class "todo-text" ] [ text todo.text ]
            ]
        , button
            [ onClick (Delete todo.id)
            , attribute "aria-label" ("Delete " ++ todo.text)
            ]
            [ text "✕" ]
        ]


footer : Model -> Html Msg
footer model =
    div [ class "footer" ]
        [ span [ class "count" ]
            [ text (String.fromInt (countActive model.todos) ++ " left") ]
        , button [ onClick ClearCompleted ] [ text "Clear completed" ]
        ]
