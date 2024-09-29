--- @brief [[
--- 
--- WindowLayout is a class that represents the recursive structure for neovim windows
--- for a given tabpage.
---
--- The structure of a Window Layout starts with a a root Row.
--- A Row can have multiple Columns, or Leaves.
--- A Column can have multiple Rows, or Leaves.
---
--- A Leaf is effectively a window, Rows and Columns just describe how they will be split.
---
--- ┌────────────────────────────────────┐
--- │             Root Row               │
--- │┌──────────┐┌─────────┐┌──────────┐ │
--- ││  Column  ││  Leaf   ││  Column  │ │
--- ││┌────────┐││         ││┌────────┐│ │
--- │││  Row   │││         │││  Leaf  ││ │
--- │││┌──┐┌──┐│││         │││        ││ │
--- ││││L ││L ││││         │││        ││ │
--- ││││e ││e ││││         │││        ││ │
--- ││││a ││a ││││         │││        ││ │
--- ││││f ││f ││││         │││        ││ │
--- │││└──┘└──┘│││         │││        ││ │
--- ││└────────┘││         ││└────────┘│ │
--- ││┌────────┐││         ││┌────────┐│ │
--- │││  Leaf  │││         │││  Leaf  ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- │││        │││         │││        ││ │
--- ││└────────┘││         ││└────────┘│ │
--- │└──────────┘└─────────┘└──────────┘ │
--- └────────────────────────────────────┘
---
---  When we render this layout, it might look something like this.
---
--- ┌─────────────┐───────────────────────────┐
--- │      │      │             │             │
--- │      │      │             │             │
--- │  L   │  L   │             │             │
--- │  o   │  o   │             │             │
--- │  g   │  g   │             │   Scratch   │
--- │  s   │  s   │             │             │
--- │      │      │             │             │
--- │      │      │             │             │
--- │      │      │   Code...   │             │
--- │─────────────┘             │─────────────┘
--- │             │             │             │
--- │             │             │             │
--- │             │             │             │
--- │             │             │             │
--- │    Docs     │             │  More Code. │
--- │             │             │             │
--- │             │             │             │
--- │             │             │             │
--- │             │             │             │
--- │             │             │             │
--- └─────────────└─────────────┘─────────────┘
--- ]]

local WindowLayout = {}
WindowLayout.__index = WindowLayout

--- @class WindowLayout
--- @field children (Row)[]

function WindowLayout:new()
  local self = setmetatable({}, WindowLayout)
  self.type = "window_layout"
  self.children = {}
  return self
end

function WindowLayout:addChild(row)
  table.insert(self.children, row)
end

return WindowLayout
