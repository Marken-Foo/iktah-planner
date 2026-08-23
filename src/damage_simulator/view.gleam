import damage_simulator.{
  type Message, type Model, UserSetMobDef, UserSetMobHp, UserSetPlayerAtk,
  UserSetPlayerCritChance, UserSetPlayerStr, UserSetWeaponSpeed, chance_to_hit,
  max_hit,
}
import gleam/float
import gleam/int
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn view(model: Model) -> element.Element(Message) {
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
    html.br([]),
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
    html.br([]),
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
    html.br([]),
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
    html.br([]),
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
    html.br([]),
    html.label([attribute.for("weapon_speed_input")], [
      html.text("Weapon time per hit: "),
    ]),
    html.input([
      attribute.id("weapon_speed_input"),
      //   attribute.min("0"),
      attribute.value(model.weapon_time_per_hit_input),
      event.on_input(UserSetWeaponSpeed),
    ]),
    html.br([]),
    html.br([]),
    html.text(
      "Damage range per hit: "
      <> "1 to "
      <> { int.to_string(max_hit(model.player_str)) },
    ),
    html.br([]),
    html.text(
      "Chance to hit: "
      <> {
        chance_to_hit(player_atk: model.player_atk, mob_def: model.mob_def)
        |> float.multiply(100.0)
        |> float.to_string()
      }
      <> "%",
    ),
    html.br([]),
    html.text(
      "Expected number of hits per kill: "
      <> {
        case model.hits_per_kill {
          Ok(hits_per_kill) -> float.to_string(hits_per_kill)
          Error(_) -> "Infinity"
        }
      },
    ),
    html.br([]),
    html.text(
      "Expected time per kill: "
      <> {
        case model.hits_per_kill {
          Ok(hits_per_kill) ->
            hits_per_kill *. model.weapon_time_per_hit |> float.to_string()
          Error(_) -> "Infinity"
        }
      },
    ),
  ])
}
