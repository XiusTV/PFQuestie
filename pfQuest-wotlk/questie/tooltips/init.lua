local Handler = QuestieLoader:ImportModule("QuestieTooltipHandler")

GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
  Handler:HandleUnit(tooltip)
end)

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
  Handler:HandleItem(tooltip)
end)

if ItemRefTooltip then
  ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    Handler:HandleItem(tooltip)
  end)
end

