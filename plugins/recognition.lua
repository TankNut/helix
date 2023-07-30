
PLUGIN.name = "Recognition"
PLUGIN.author = "Chessnut"
PLUGIN.description = "Adds the ability to recognize people."

ix.config.Add("scoreboardRecognition", false, "Whether or not recognition is used in the scoreboard.", nil, {
	category = "characters"
})

do
	local characterMeta = ix.meta.character

	if (SERVER) then
		function characterMeta:Recognize(id)
			if (!isnumber(id) and id.GetID) then
				id = id:GetID()
			end

			local recognized = self:GetData("rgn", "")

			if (recognized != "" and recognized:find("," .. id .. ",")) then
				return false
			end

			self:SetData("rgn", recognized .. "," .. id .. ",")

			return true
		end
	end

	function characterMeta:DoesRecognize(character)
		return hook.Run("IsCharacterRecognized", self, character)
	end

	function GAMEMODE:IsCharacterRecognized(character, target)
		if (character == target) then
			return true
		end

		local faction = ix.faction.indices[target:GetFaction()]

		if (faction and faction.isGloballyRecognized) then
			return true
		end

		local recognized = character:GetData("rgn", "")

		return recognized != "" and recognized:find("," .. target:GetID() .. ",")
	end
end

if (CLIENT) then
	CHAT_RECOGNIZED = CHAT_RECOGNIZED or {}
	CHAT_RECOGNIZED["ic"] = true
	CHAT_RECOGNIZED["y"] = true
	CHAT_RECOGNIZED["w"] = true
	CHAT_RECOGNIZED["me"] = true

	function GAMEMODE:IsRecognizedChatType(chatType)
		if (CHAT_RECOGNIZED[chatType]) then
			return true
		end
	end

	function PLUGIN:GetCharacterName(character)
		if (!LocalPlayer():GetCharacter():DoesRecognize(character)) then
			return L("unknown")
		end
	end

	function PLUGIN:GetSpeakerName(client, chatType)
		local character = client:GetCharacter()

		if (hook.Run("IsRecognizedChatType", chatType) and !LocalPlayer():GetCharacter():DoesRecognize(character)) then
			local description = character:GetDisplayDescription()

			if (#description > 40) then
				description = description:utf8sub(1, 37) .. "..."
			end

			return "[" .. description .. "]"
		end
	end

	function PLUGIN:ScoreboardUpdatePlayer(panel, client)
		if (!ix.config.Get("scoreboardRecognition")) then
			return
		end

		local character = IsValid(client) and client:GetCharacter()
		local bRecognize = character and LocalPlayer():GetCharacter():DoesRecognize(character)

		if (!bRecognize) then
			panel:SetDescription(L("noRecog"))
		end

		panel.icon:SetHidden(!bRecognize)
		panel:SetZPos(bRecognize and 1 or 2)
	end

	local function Recognize(level)
		net.Start("ixRecognize")
			net.WriteUInt(level, 2)
		net.SendToServer()
	end

	net.Receive("ixRecognizeMenu", function(length)
		local menu = DermaMenu()
			menu:AddOption(L"rgnLookingAt", function()
				Recognize(0)
			end)
			menu:AddOption(L"rgnWhisper", function()
				Recognize(1)
			end)
			menu:AddOption(L"rgnTalk", function()
				Recognize(2)
			end)
			menu:AddOption(L"rgnYell", function()
				Recognize(3)
			end)
		menu:Open()
		menu:MakePopup()
		menu:Center()
	end)

	net.Receive("ixRecognizeDone", function(length)
		hook.Run("CharacterRecognized")
	end)

	function PLUGIN:CharacterRecognized(client, recogCharID)
		surface.PlaySound("buttons/button17.wav")
	end
else
	util.AddNetworkString("ixRecognize")
	util.AddNetworkString("ixRecognizeMenu")
	util.AddNetworkString("ixRecognizeDone")

	function PLUGIN:ShowSpare1(client)
		if (client:GetCharacter()) then
			net.Start("ixRecognizeMenu")
			net.Send(client)
		end
	end

	net.Receive("ixRecognize", function(length, client)
		local level = net.ReadUInt(2)

		if (isnumber(level)) then
			local targets = {}

			if (level < 1) then
				local entity = client:GetEyeTraceNoCursor().Entity

				if (IsValid(entity) and entity:IsPlayer() and entity:GetCharacter()
				and ix.chat.classes.ic:CanHear(client, entity)) then
					targets[1] = entity
				end
			else
				local class = "w"

				if (level == 2) then
					class = "ic"
				elseif (level == 3) then
					class = "y"
				end

				class = ix.chat.classes[class]

				for _, v in ipairs(player.GetAll()) do
					if (client != v and v:GetCharacter() and class:CanHear(client, v)) then
						targets[#targets + 1] = v
					end
				end
			end

			if (#targets > 0) then
				local id = client:GetCharacter():GetID()
				local i = 0

				for _, v in ipairs(targets) do
					if (v:GetCharacter():Recognize(id)) then
						i = i + 1
					end
				end

				if (i > 0) then
					net.Start("ixRecognizeDone")
					net.Send(client)

					hook.Run("CharacterRecognized", client, id)
				end
			end
		end
	end)
end
