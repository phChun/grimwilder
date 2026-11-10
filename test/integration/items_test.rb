require "test_helper"

class ItemsTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs) # pip's, at gwen's table
    @campaign = campaigns(:bramblewood)
  end

  test "the owner adds an item from the sheet's modal form, beside the arcana" do
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#arcana h2", "Arcana and items"
    assert_select "#arcana a[href=?][data-turbo-frame=modal]", new_character_item_path(@tibbs), "Add item"

    get new_character_item_path(@tibbs)
    assert_select "turbo-frame#modal h1", "New item"

    post character_items_path(@tibbs), params: { item: { name: "  Map to the  Sunken Abbey ", description: "Drawn by a dying monk. " } }
    map = @tibbs.items.sole
    assert_redirected_to character_path(@tibbs, anchor: "item-#{map.id}")
    assert_equal "Map to the Sunken Abbey", map.name
    assert_equal "Drawn by a dying monk.", map.description
    assert_equal "Gibbletibble \"Tibbs\" gains Map to the Sunken Abbey", @campaign.rolls.note.last.question

    get character_path(@tibbs)
    assert_select "#item-#{map.id} .talent-card__name", "Map to the Sunken Abbey"
    assert_select "#item-#{map.id} details.talent-card__fold summary .talent-card__summary", "Drawn by a dying monk."
    assert_select "#item-#{map.id} .talent-card__body .talent-card__text", "Drawn by a dying monk."
    assert_select "#item-#{map.id} .talent-card__actions a[href=?]", edit_character_item_path(@tibbs, map), "Edit"
    assert_select "#item-#{map.id} .talent-card__actions form[action=?] button", character_item_path(@tibbs, map), "Remove"
    assert_select "#item-#{map.id} .talent-card__more-menu", 0
    assert_select "#item-#{map.id} .use-tally__count", 0, "not counted unless asked"
    patch character_item_count_path(@tibbs, map), params: { by: 1 }
    assert_response :not_found
  end

  test "a nameless item shows the form again" do
    sign_in_as identities(:pip)
    post character_items_path(@tibbs), params: { item: { name: "" } }

    assert_response :unprocessable_entity
    assert_select ".form-error", /Name can't be blank/
    assert_empty @tibbs.items
  end

  test "the GM can change a player's items; other players can't; strangers get a 404" do
    key = @tibbs.items.create!(name: "Key")

    sign_in_as identities(:gwen)
    patch character_item_path(@tibbs, key), params: { item: { name: "Iron key" } }
    assert_equal "Iron key", key.reload.name

    sign_out
    sign_in_as identities(:pip)
    get new_character_item_path(characters(:bram))
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    delete character_item_path(@tibbs, key)
    assert_response :not_found
    assert Item.exists?(key.id)
  end

  test "other viewers see items without the controls; the owner removes one" do
    letter = characters(:bram).items.create!(name: "Sealed letter")

    sign_in_as identities(:pip)
    get character_path(characters(:bram))
    assert_select "#arcana .talent-card__name", "Sealed letter"
    assert_select "#arcana a", 0
    assert_select "#arcana form", 0

    key = @tibbs.items.create!(name: "Key")
    delete character_item_path(@tibbs, key)
    assert_redirected_to character_path(@tibbs, anchor: "arcana")
    assert_not Item.exists?(key.id)
    assert Item.exists?(letter.id)
  end

  test "the owner counts an item up and down from the sheet, never below none" do
    rope = @tibbs.items.create!(name: "Rope", counted: true, quantity: 1)
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#item-#{rope.id} .use-tally__count", "1"
    assert_select "#item-#{rope.id} form[action=?] input[name=by][value='1']", character_item_count_path(@tibbs, rope)

    patch character_item_count_path(@tibbs, rope), params: { by: 1 }
    assert_redirected_to character_path(@tibbs, anchor: "item-#{rope.id}")
    assert_equal 2, rope.reload.quantity

    patch character_item_count_path(@tibbs, rope), params: { by: -1 }
    patch character_item_count_path(@tibbs, rope), params: { by: -1 }
    patch character_item_count_path(@tibbs, rope), params: { by: -1 }
    assert_equal 0, rope.reload.quantity
    get character_path(@tibbs)
    assert_select "#item-#{rope.id} button.use-tally__step[disabled][aria-label=?]", "One fewer Rope"

    patch character_item_count_path(@tibbs, rope), params: { by: 50 }
    assert_equal 1, rope.reload.quantity, "one at a time"
  end

  test "the form sets how many; other players see the count without buttons" do
    sign_in_as identities(:pip)
    post character_items_path(@tibbs), params: { item: { name: "Torch", counted: "1", quantity: "3" } }
    assert_equal [ true, 3 ], @tibbs.items.sole.values_at(:counted, :quantity)

    post character_items_path(@tibbs), params: { item: { name: "Torch", quantity: "-1" } }
    assert_response :unprocessable_entity

    characters(:bram).items.create!(name: "Coin purse", counted: true, quantity: 12)
    get character_path(characters(:bram))
    assert_select "#arcana .talent-card__summary", "12 carried"
    assert_select "#arcana .use-tally__count", "12"
    assert_select "#arcana .use-tally__step", 0

    patch character_item_count_path(characters(:bram), characters(:bram).items.sole), params: { by: 1 }
    assert_response :forbidden
  end
end
