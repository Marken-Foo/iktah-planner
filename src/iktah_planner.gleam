import lustre
import lustre/effect
import lustre/element
import lustre/element/html

import damage_simulator as dmgsim
import xp

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type Model {
  Model(xp_model: xp.Model, damage_simulator_model: dmgsim.Model)
}

type Message {
  XpMessage(xp.Message)
  DamageSimulatorMessage(dmgsim.Message)
}

fn init(_) -> #(Model, effect.Effect(Message)) {
  let #(xp_model, xp_effect) = xp.init(Nil)
  let #(damage_simulator_model, damage_simulator_effect) = dmgsim.init(Nil)
  #(
    Model(xp_model:, damage_simulator_model:),
    effect.batch([
      effect.map(xp_effect, XpMessage),
      effect.map(damage_simulator_effect, DamageSimulatorMessage),
    ]),
  )
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(Message)) {
  case message {
    XpMessage(msg) -> {
      let #(submodel, subeffect) = xp.update(model.xp_model, msg)
      #(Model(..model, xp_model: submodel), subeffect |> effect.map(XpMessage))
    }
    DamageSimulatorMessage(msg) -> {
      let #(submodel, subeffect) =
        dmgsim.update(model.damage_simulator_model, msg)
      #(
        Model(..model, damage_simulator_model: submodel),
        subeffect |> effect.map(DamageSimulatorMessage),
      )
    }
  }
}

fn view(model: Model) -> element.Element(Message) {
  html.div([], [
    html.h1([], [html.text("Idle Iktah calculators")]),
    html.h2([], [html.text("XP needed calculator")]),
    xp.view(model.xp_model) |> element.map(XpMessage),
    html.hr([]),
    html.h2([], [html.text("Damage simulator calculator")]),
    dmgsim.view(model.damage_simulator_model)
      |> element.map(DamageSimulatorMessage),
  ])
}
