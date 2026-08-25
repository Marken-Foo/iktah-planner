import damage_simulator.{
  type Message, type Model, UserSetMobDef, UserSetMobHp, UserSetPlayerAtk,
  UserSetPlayerCritChance, UserSetPlayerStr, UserSetWeapon,
} as dsim
import damage_simulator/weapon
import gleam/float
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn view(model: Model) -> element.Element(Message) {
  html.form([attribute.class("stat-inputs")], [
    weapon_dropdown(model),
    html.div([], [
      html.label([attribute.for("player_atk_input")], [
        html.text("Player ATK: "),
      ]),
      html.input([
        attribute.type_("number"),
        attribute.id("player_atk_input"),
        attribute.min("1"),
        attribute.value(model.player_atk |> int.to_string()),
        event.on_input(UserSetPlayerAtk),
      ]),
      html.text("+" <> model.weapon.atk |> int.to_string()),
      html.text(" = " <> model.player_atk + model.weapon.atk |> int.to_string()),
    ]),
    html.div([], [
      html.label([attribute.for("player_str_input")], [
        html.text("Player STR: "),
      ]),
      html.input([
        attribute.type_("number"),
        attribute.id("player_str_input"),
        attribute.min("1"),
        attribute.value(model.player_str |> int.to_string()),
        event.on_input(UserSetPlayerStr),
      ]),
      html.text("+" <> model.weapon.str |> int.to_string()),
      html.text(" = " <> model.player_str + model.weapon.str |> int.to_string()),
    ]),
    html.div([], [
      html.text("Player crit chance: "),
      html.input([
        attribute.type_("number"),
        attribute.id("player_crit_chance"),
        attribute.min("0"),
        attribute.max("100"),
        attribute.value(
          model.player_crit_chance
          |> float.multiply(100.0)
          |> float.truncate()
          |> int.to_string(),
        ),
        event.on_input(UserSetPlayerCritChance),
      ]),
      html.text("%"),
    ]),
    html.div([], [
      html.label([attribute.for("mob_def_input")], [
        html.text("Mob DEF: "),
      ]),
      html.input([
        attribute.type_("number"),
        attribute.id("mob_def_input"),
        attribute.min("1"),
        attribute.value(model.mob_def |> int.to_string()),
        event.on_input(UserSetMobDef),
      ]),
    ]),
    html.div([], [
      html.label([attribute.for("mob_hp_input")], [
        html.text("Mob HP: "),
      ]),
      html.input([
        attribute.type_("number"),
        attribute.id("mob_hp_input"),
        attribute.min("1"),
        attribute.value(model.mob_hp |> int.to_string()),
        event.on_input(UserSetMobHp),
      ]),
    ]),
    html.div([], [
      html.label([attribute.for("weapon_speed_input")], [
        html.text("Weapon time per hit: "),
      ]),
      html.input([
        attribute.id("weapon_speed_input"),
        attribute.value(model.weapon.time_per_hit |> float.to_string()),
        attribute.disabled(True),
      ]),
    ]),
    damage_output_view(model),
  ])
}

fn weapon_dropdown(model: Model) -> element.Element(Message) {
  let weapon_ids = [
    "none",
    "kings-klaws",
    "arborbiter",
    "klynite-dagger",
    "alchemists-kris",
    "shadow-dagger",
  ]

  html.div([], [
    html.label([attribute.for("weapon_input")], [
      html.text("Weapon: "),
    ]),
    html.select(
      [
        attribute.id("weapon_input"),
        event.on_input(UserSetWeapon),
      ],
      list.map(weapon_ids, fn(id) {
        let w = weapon.by_id(id)
        html.option(
          [attribute.value(w.id), attribute.selected(id == model.weapon.id)],
          w.name,
        )
      }),
    ),
  ])
}

fn damage_output_view(model: Model) -> element.Element(Message) {
  let total_atk = model.player_atk + model.weapon.atk
  let total_str = model.player_str + model.weapon.str

  let hits_per_kill =
    dsim.hits_per_kill(
      player_atk: total_atk,
      player_str: total_str,
      mob_def: model.mob_def,
      mob_hp: model.mob_hp,
      player_crit_chance: model.player_crit_chance,
    )

  element.fragment([
    html.text(
      "Damage range per hit: "
      <> "1 to "
      <> { int.to_string(dsim.max_hit(total_str)) },
    ),
    html.br([]),
    html.text(
      "Chance to hit: "
      <> dsim.chance_to_hit(player_atk: total_atk, mob_def: model.mob_def)
      |> float.multiply(100.0)
      |> float.to_string()
      <> "%",
    ),
    html.br([]),
    html.text(
      "Expected number of hits per kill: "
      <> case hits_per_kill {
        Ok(hits_per_kill) -> float.to_string(hits_per_kill)
        Error(_) -> "Infinity"
      },
    ),
    html.br([]),
    html.text(
      "Expected time per kill: "
      <> case hits_per_kill {
        Ok(hits_per_kill) ->
          hits_per_kill *. model.weapon.time_per_hit |> float.to_string()
        Error(_) -> "Infinity"
      },
    ),
  ])
}
