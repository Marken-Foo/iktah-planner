import gleam/float
import gleam/int
import gleam/result
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

import probability as probs

pub type Model {
  Model(
    player_atk: Int,
    player_str: Int,
    player_crit_chance: Float,
    mob_def: Int,
    mob_hp: Int,
    weapon_time_per_hit_input: String,
    weapon_time_per_hit: Float,
    hits_per_kill: Result(Float, Nil),
  )
}

pub type Message {
  UserSetPlayerAtk(String)
  UserSetPlayerStr(String)
  UserSetPlayerCritChance(String)
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
    player_crit_chance: 0.05,
    weapon_time_per_hit_input: "2.0",
    weapon_time_per_hit: 2.0,
    hits_per_kill: Error(Nil),
  )
  |> update_hits_per_kill()
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
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetPlayerStr(str) -> {
      let player_str = int.parse(str) |> result.unwrap(model.player_str)
      model
      |> fn(m) { Model(..m, player_str:) }
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetPlayerCritChance(str) -> {
      let player_crit_chance =
        int.parse(str)
        |> result.map(int.to_float)
        |> result.try(float.divide(_, by: 100.0))
        |> result.unwrap(model.player_crit_chance)
      model
      |> fn(m) { Model(..m, player_crit_chance:) }
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobDef(str) -> {
      let mob_def = int.parse(str) |> result.unwrap(model.mob_def)
      model
      |> fn(m) { Model(..m, mob_def:) }
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobHp(str) -> {
      let mob_hp = int.parse(str) |> result.unwrap(model.mob_hp)
      model
      |> fn(m) { Model(..m, mob_hp:) }
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetWeaponSpeed(str) -> {
      let weapon_time_per_hit =
        float.parse(str)
        |> result.try_recover(fn(_) {
          int.parse(str) |> result.map(int.to_float)
        })
        |> result.unwrap(model.weapon_time_per_hit)
      model
      |> fn(m) {
        Model(..m, weapon_time_per_hit_input: str, weapon_time_per_hit:)
      }
      |> update_hits_per_kill()
      |> fn(m) { #(m, effect.none()) }
    }
  }
}

fn update_hits_per_kill(model: Model) -> Model {
  let hits_per_kill =
    hits_per_kill(
      player_atk: model.player_atk,
      player_str: model.player_str,
      mob_def: model.mob_def,
      mob_hp: model.mob_hp,
      player_crit_chance: model.player_crit_chance,
    )
  Model(..model, hits_per_kill:)
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

type Damage =
  Int

type Probability =
  Float

fn clamp_probability(p: Float) -> Probability {
  p |> float.max(0.0) |> float.min(1.0)
}

fn chance_to_hit(
  player_atk player_atk: Int,
  mob_def mob_def: Int,
) -> Probability {
  { 50.0 +. 0.75 *. int.to_float(player_atk - mob_def) }
  |> fn(p) { p /. 100.0 }
  |> clamp_probability()
}

fn max_hit(player_str: Int) -> Damage {
  1 + player_str / 3
}

fn apply_crit_rolls(
  base_pmf: probs.Pmf,
  player_crit_chance: Float,
) -> probs.Pmf {
  // Roll twice
  let crit_pmf = probs.multiply_pmfs(base_pmf, base_pmf)
  // On a given hit, chance of p to crit and 1-p to not crit
  probs.add_pmfs(crit_pmf, clamp_probability(player_crit_chance), base_pmf)
}

fn apply_miss_chance(
  base_pmf: probs.Pmf,
  chance_to_hit: Probability,
) -> probs.Pmf {
  base_pmf |> probs.scale_and_reassign_probability(chance_to_hit, 0)
}

fn hits_per_kill(
  player_atk player_atk: Int,
  player_str player_str: Int,
  mob_def mob_def: Int,
  mob_hp mob_hp: Int,
  player_crit_chance player_crit_chance: Float,
) -> Result(Float, Nil) {
  let pmf_of_one_attack =
    probs.uniform_pmf(1, max_hit(player_str))
    |> apply_miss_chance(chance_to_hit(player_atk, mob_def))
    |> apply_crit_rolls(player_crit_chance)
  probs.expected_rolls_to_exceed_total_k(mob_hp, pmf_of_one_attack)
}
