import lustre
import lustre/effect
import lustre/element
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

type Model {
  Model(str: String)
}

type Message

fn init(_) -> #(Model, effect.Effect(Message)) {
  #(Model("Hellomoto"), effect.none())
}

fn update(model: Model, message: Message) -> #(Model, effect.Effect(Message)) {
  case message {
    _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> element.Element(Message) {
  html.text(model.str)
}
