module Verify.Contract exposing (Surface, surfaceContractChecks, verifyAttrs)

{-| Idea #1: the DOM is the machine-readable surface.

A `Surface` is the list of `(key, value)` pairs a unit promises to expose on the
DOM as `data-verify-*` attributes. The *same* `Surface` value feeds both:

  - `verifyAttrs` — what the view renders, and
  - the invariants / contract checks — what the verifiers read.

Because both sides read one value, the contract cannot silently drift from the
rendered markup. Refactor the internals freely; as long as the surface holds,
verifiers keep passing.

-}

import Html exposing (Attribute)
import Html.Attributes exposing (attribute)
import Verify.Core exposing (Check, CheckStatus(..))


{-| The promised machine-readable state of a unit.
-}
type alias Surface =
    List ( String, String )


{-| Render a surface as `data-verify-*` attributes on a DOM node.

    section (verifyAttrs (surface model)) [ ... ]

produces e.g.

    <section data-verify-unit="TodoApp" data-verify-total="3" ...>

-}
verifyAttrs : Surface -> List (Attribute msg)
verifyAttrs pairs =
    List.map (\( key, value ) -> attribute ("data-verify-" ++ key) value) pairs


{-| The `dom-contract` verifier, pure half: a well-formed surface must be
non-empty and self-identifying (carry a `unit` key). The browser/Playwright
half confirms these attributes are actually present on the live DOM.
-}
surfaceContractChecks : Surface -> List Check
surfaceContractChecks surface =
    let
        hasUnit =
            List.any (\( k, _ ) -> k == "unit") surface

        nonEmpty =
            not (List.isEmpty surface)
    in
    [ { verifier = "dom-contract"
      , name = "self-identifying"
      , status =
            if hasUnit then
                Ok_

            else
                FailC
      , detail =
            if hasUnit then
                "surface carries a `unit` key"

            else
                "surface is missing the `unit` key — node is not self-identifying"
      }
    , { verifier = "dom-contract"
      , name = "non-empty-surface"
      , status =
            if nonEmpty then
                Ok_

            else
                FailC
      , detail =
            if nonEmpty then
                "surface exposes " ++ String.fromInt (List.length surface) ++ " attribute(s)"

            else
                "surface is empty — nothing is observable"
      }
    ]
