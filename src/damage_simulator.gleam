import gleam/float
import gleam/int
import gleam/result
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

import probability_mass_function as pmf

pub type Model {
  Model(
    player_atk: Int,
    player_str: Int,
    mob_def: Int,
    mob_hp: Int,
    weapon_time_per_hit_input: String,
    weapon_time_per_hit: Float,
    time_per_kill: Result(Float, Nil),
  )
}

pub type Message {
  UserSetPlayerAtk(String)
  UserSetPlayerStr(String)
  UserSetMobDef(String)
  UserSetMobHp(String)
  UserSetWeaponSpeed(String)
}

pub fn init(_) -> #(Model, effect.Effect(Message)) {
  Model(
    player_atk: 1,
    player_str: 1,
    mob_def: 1,
    mob_hp: 120,
    weapon_time_per_hit_input: "2.0",
    weapon_time_per_hit: 2.0,
    time_per_kill: Error(Nil),
  )
  |> update_time_per_kill()
  |> fn(m) { #(m, effect.none()) }
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    UserSetPlayerAtk(str) -> {
      let player_atk = int.parse(str) |> result.unwrap(model.player_atk)
      model
      |> fn(m) { Model(..m, player_atk:) }
      |> update_time_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetPlayerStr(str) -> {
      let player_str = int.parse(str) |> result.unwrap(model.player_str)
      model
      |> fn(m) { Model(..m, player_str:) }
      |> update_time_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobDef(str) -> {
      let mob_def = int.parse(str) |> result.unwrap(model.mob_def)
      model
      |> fn(m) { Model(..m, mob_def:) }
      |> update_time_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobHp(str) -> {
      let mob_hp = int.parse(str) |> result.unwrap(model.mob_hp)
      model
      |> fn(m) { Model(..m, mob_hp:) }
      |> update_time_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetWeaponSpeed(str) -> {
      let weapon_time_per_hit =
        float.parse(str) |> result.unwrap(model.weapon_time_per_hit)
      model
      |> fn(m) {
        Model(..m, weapon_time_per_hit_input: str, weapon_time_per_hit:)
      }
      |> update_time_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
  }
}

fn update_time_per_kill(model: Model) -> Model {
  let time_per_kill =
    time_per_kill(
      player_atk: model.player_atk,
      player_str: model.player_str,
      mob_def: model.mob_def,
      mob_hp: model.mob_hp,
      weapon_time_per_hit: model.weapon_time_per_hit,
    )
  Model(..model, time_per_kill:)
}

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
    html.text(
      "Time per kill: "
      <> {
        case model.time_per_kill {
          Ok(time_per_kill) -> float.to_string(time_per_kill)
          Error(_) -> "Infinity"
        }
      },
    ),
  ])
}

type Damage =
  Int

type Probability =
  Float

fn clamp_probability(p: Float) -> Probability {
  p |> float.max(0.0) |> float.min(1.0)
}

fn chance_to_hit(player_atk: Int, mob_def: Int) -> Probability {
  { 50.0 +. 0.75 *. int.to_float(player_atk - mob_def) }
  |> fn(p) { p /. 100.0 }
  |> clamp_probability()
}

fn max_hit(player_str: Int) -> Damage {
  1 + player_str / 3
}

fn apply_miss_chance(base_pmf: pmf.Pmf, chance_to_hit: Probability) -> pmf.Pmf {
  base_pmf |> pmf.scale_and_reassign_probability(chance_to_hit, 0)
}

fn time_per_kill(
  player_atk player_atk: Int,
  player_str player_str: Int,
  mob_def mob_def: Int,
  mob_hp mob_hp: Int,
  weapon_time_per_hit weapon_time_per_hit: Float,
) -> Result(Float, Nil) {
  let pmf_of_one_attack =
    pmf.uniform_pmf(1, max_hit(player_str))
    // TODO: Implement crit damage calculations
    |> apply_miss_chance(chance_to_hit(player_atk, mob_def))
  let expected_number_of_rolls =
    pmf.expected_rolls_to_exceed_total_k(mob_hp, pmf_of_one_attack)
  expected_number_of_rolls |> result.map(float.multiply(_, weapon_time_per_hit))
}
