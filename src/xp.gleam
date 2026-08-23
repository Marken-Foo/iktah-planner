import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

type Model {
  Model(current_xp: Xp, current_level: Int, target_level: Int)
}

type Message {
  UserSetCurrentLevel(String)
  UserSetCurrentXp(String)
  UserSetTargetLevel(String)
}

fn init(_) -> #(Model, effect.Effect(Message)) {
  let starting_xp = Xp(0)
  let #(starting_level, _) = level_given_total_xp(starting_xp)
  #(
    Model(
      current_xp: starting_xp,
      current_level: starting_level,
      target_level: 99,
    ),
    effect.none(),
  )
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(Message)) {
  case message {
    UserSetCurrentLevel(str) -> {
      let current_level = int.parse(str) |> result.unwrap(model.current_level)
      let current_xp =
        xp_needed(from_level: 1, to_level: current_level)
        |> result.unwrap(model.current_xp)
      #(Model(..model, current_xp:, current_level:), effect.none())
    }
    UserSetCurrentXp(str) -> {
      let current_xp =
        int.parse(str) |> result.map(Xp) |> result.unwrap(model.current_xp)
      let #(current_level, _) = level_given_total_xp(current_xp)
      let current_level = int.min(current_level, 99)
      #(Model(..model, current_xp:, current_level:), effect.none())
    }
    UserSetTargetLevel(str) -> {
      let target_level = int.parse(str) |> result.unwrap(model.target_level)
      #(Model(..model, target_level:), effect.none())
    }
  }
}

fn view(model: Model) -> element.Element(Message) {
  view_xp_calc(model)
}

fn view_xp_calc(model: Model) -> element.Element(Message) {
  let Xp(current_xp) = model.current_xp
  let target_xp_needed = xp_needed(1, model.target_level)
  let remaining_xp_needed =
    target_xp_needed
    |> result.map(fn(xp) {
      let Xp(xp) = xp
      Xp(xp - current_xp)
    })
    |> result.map(fn(xp) {
      let Xp(xp) = xp
      commatize_int(xp)
    })
    |> result.unwrap("Invalid target level.")
  html.div([], [
    html.label([attribute.for("current_level_input")], [
      html.text("Current level: "),
    ]),
    html.input([
      attribute.type_("number"),
      attribute.id("current_level_input"),
      attribute.min("1"),
      attribute.max("99"),
      attribute.value(model.current_level |> int.to_string()),
      event.on_input(UserSetCurrentLevel),
    ]),
    html.br([]),
    html.label([attribute.for("current_xp_input")], [html.text("Current XP: ")]),
    html.input([
      attribute.type_("number"),
      attribute.id("current_xp_input"),
      attribute.min("0"),
      attribute.value(current_xp |> int.to_string()),
      event.on_input(UserSetCurrentXp),
    ]),
    html.br([]),
    html.label([attribute.for("target_level_input")], [
      html.text("Target level: "),
    ]),
    html.input([
      attribute.type_("number"),
      attribute.id("target_level_input"),
      attribute.min("1"),
      attribute.max("99"),
      attribute.value(model.target_level |> int.to_string()),
      event.on_input(UserSetTargetLevel),
    ]),
    html.br([]),
    html.text("XP needed: " <> { remaining_xp_needed }),
  ])
}

fn commatize_int(number: Int) -> String {
  case number {
    x if x < 0 -> "-" <> commatize_int_([], -x)
    x -> commatize_int_([], x)
  }
}

fn commatize_int_(acc: List(Int), number: Int) -> String {
  case number {
    x if x < 0 -> number |> int.to_string()
    x if 0 <= x && x < 1000 -> {
      acc
      |> list.map(int.to_string)
      |> list.map(string.pad_start(_, to: 3, with: "0"))
      |> fn(strs) { [int.to_string(x), ..strs] }
      |> string.join(",")
    }
    x -> {
      let q = x / 1000
      let r = x % 1000
      commatize_int_([r, ..acc], q)
    }
  }
}

// type
type Duration {
  Seconds(Float)
}

type Skill {
  Woodcutting
  Mining
  Fishing
  Gathering
  Tracking
  Crafting
  Smithing
  Cooking
  Alchemy
  Tailoring
  Carpentry
  Enchanting
  Community
  Landkeeping
}

type Action {
  Action(xp: Xp, skill: Skill, time: Duration)
}

type Xp {
  Xp(Int)
}

fn level_given_total_xp(xp: Xp) -> #(Int, Xp) {
  level_given_total_xp_(#(1, xp))
}

fn level_given_total_xp_(acc: #(Int, Xp)) -> #(Int, Xp) {
  let #(level, Xp(xp)) = acc
  let Xp(needed_xp) = xp_to_next_level(level)
  case xp - needed_xp {
    balance if balance < 0 -> acc
    balance -> level_given_total_xp_(#(level + 1, Xp(balance)))
  }
}

fn xp_to_next_level(start_level: Int) -> Xp {
  float.truncate(
    633.0
    /. 11.0
    *. {
      float.power(2.0, int.to_float(start_level) /. 7.0) |> result.unwrap(1.0)
    },
  )
  |> Xp()
}

fn xp_needed(
  from_level start_level: Int,
  to_level end_level: Int,
) -> Result(Xp, Nil) {
  xp_needed_(Ok(Xp(0)), start_level, end_level)
}

fn xp_needed_(
  acc: Result(Xp, Nil),
  start_level: Int,
  end_level: Int,
) -> Result(Xp, Nil) {
  case start_level {
    start_level if start_level == end_level -> acc
    start_level if start_level > end_level -> Error(Nil)
    start_level ->
      xp_needed_(
        acc
          |> result.map(fn(xp) {
            case xp, xp_to_next_level(start_level) {
              Xp(xp), Xp(xp_to_level) -> Xp(xp + xp_to_level)
            }
          }),
        start_level + 1,
        end_level,
      )
  }
}
