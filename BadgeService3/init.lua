--[[
	BadgeService3! 		>> By LucasMZReal.

		BadgeService3 is a module which allows you to use DataStores to
		have badges, instead of paying 100 robux to Roblox to do that.
		Everything is managed by you, and you only.

		BadgeService3 is meant with people having their own data-storing in mind!
		It doesn't handle the datastoring for you, but instead give you the tools to work
			with BadgeService3 and save that data with your normal data.

		It's compatible with basically any type of datastore module out there,
		like ProfileService, DataStore2, and many others.

		↓ You can find the documentation here.

		Functions:
		
			:LoadProfile
			
			Parameters: player, badgeData
			Returns: BadgeProfile
			\\ Loads a Badge Profile into the module.

			:FindFirstProfile

			Parameters: player
			Returns: BadgeProfile / nil
			\\ Tries to find an already loaded profile, returns nil if none is found.

			:WaitForProfile

			Parameters: player
			Returns: BadgeProfile / nil
			\\ Same as FindFirstProfile, except it will yield until one is loaded, or until the player leaves.

			:GetBadges

			Parameters: nil
			Returns: Badges, BadgesAmount
			\\ Returns all set-up badges, should be used for client replication.

			:GetBadgeCount

			Parameters: nil
			Returns: BadgesAmount
			\\ Returns the amount of badges set-up.

			:SetGlobalSettings

			Parameters: table \ dictionary (with the keys as the setting's names, and the values as their new settings.)
			Returns: nil
			\\ Changes settings based on a table.

	BadgeProfile:

		Functions:

			:AwardBadge

			Parameters: badgeId
			Returns: nil
			\\ Awards a badge!

			:RemoveBadge

			Parameters: badgeId
			Returns: nil
			\\ Removes a badge.

			:OwnsBadge

			Parameters: badgeId
			Returns: boolean
			\\ Returns a boolean telling if a player owns a badge.

		Events:

			.OnUpdate

			Arguments: Copied-data used for updating your data when it needs to
					   For DS2 / ProfileService where you need to update data as it changes.
			
			\\ Fires when BadgeProfile.Data changes via a function.
				You shouldn't mutate .Data yourself, please don't.
			  \ You also shouldn't try to get data directly from it,
				all of that should be all handled by BadgeService3,
				try to use as much using BadgeService3 as you can without checking .Data!

			
			.OnBadgeAwarded

			Arguments: badgeId (from the badge that was awarded)

			\\ Should be used for custom notification integration.

		Version: 3.0.0 (09/06/2021)
					    DD/MM/YYYY
]]

local SETTINGS = {
	usesBadgeImageForNotifications = false;
	isNotificationsDisabled = false;
	usesGoldBadgeNotification = false;
	defaultBadgeNotificationImage = "rbxassetid://6170641771";
	notificationDuration = 5;
	NotificationDescription = 'You have been awarded "%s"!';
	NotificationTitle = "Badge Awarded!"
}

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local RunService = game:GetService("RunService");
local Signal = require(script:WaitForChild("Signal"));
local Badges = require(script:WaitForChild("Badges"));

local BADGE_PROFILES = {};
local ON_BADGE_PROFILE_LOADED = Signal.new();

local BadgeService3 = {};

local BadgeProfile = {};
BadgeProfile.__index = BadgeProfile;

--\\ Init:

local Remote_Notification = script:FindFirstChild("Notification") or Instance.new("RemoteEvent")
Remote_Notification.Parent = script;
Remote_Notification.Name = "Notification"


--\\ Private functions;

local function ShallowCopy(t)
	local copy = table.create(#t)
	for index, value in pairs(t) do
		copy[index] = value;
	end
	return copy;
end

local function IsTableEmpty(t)
	return next(t) == nil
end

local function ConvertTrueDictionaryToArray(self)
	--\\ Transforms {[badgeId] = true} to {badgeId1, badgeId2}

	if self.Data[1] or IsTableEmpty(self.Data) then
		return;
	end

	--
	local converted = {};
	for badgeId, isOwned in pairs(self.Data) do
		if isOwned then
			table.insert(converted, badgeId)
		end
	end

	
	self.Data = converted;
	self.OnUpdate:Fire(
		ShallowCopy(self.Data)
	);	
end


local function GetNotificationData(badgeId)
	local badgeInfo = Badges[badgeId];

	local imageURL = SETTINGS.usesBadgeImageForNotifications and ( tonumber(badgeInfo.Image) and 'rbxassetid://'.. badgeInfo.Image )
					 or (SETTINGS.usesGoldBadgeNotification and 'rbxassetid://206410289' or SETTINGS.defaultBadgeNotificationImage)
	--\\ I might be a little bit too much, um obsessed with this..

	return {
		Title = SETTINGS.NotificationTitle:format(
			badgeInfo.Name
		);
		Text = SETTINGS.NotificationDescription:format(
			badgeInfo.Name
		);
		Icon = imageURL;
		Duration = SETTINGS.notificationDuration;
	}
end

--\\ Public functions

function BadgeService3:LoadProfile(player, badgeData)
	assert(
		typeof(player) == "Instance" and player:IsA("Player"),
		"Invalid :WaitForProfile parameter."
	)

	if BADGE_PROFILES[player] then return BADGE_PROFILES[player] end;

	if (typeof(badgeData) == 'table') or (badgeData == nil) then
		badgeData = badgeData or {};
	else
		warn("BadgeService3: :LoadProfile was called with invalid data, it instead resulted in no data.")
		badgeData = {};
	end

	local badgeProfile = setmetatable({
		Data = badgeData;
		OnUpdate = Signal.new('OnUpdate');
		OnBadgeAwarded = Signal.new('OnBadgeAwarded');
		_player = player;
	}, BadgeProfile)

	badgeProfile.onUpdate = badgeProfile.OnUpdate;
	badgeProfile.onBadgeAwarded = badgeProfile.OnBadgeAwarded;

	BADGE_PROFILES[player] = badgeProfile;
	ON_BADGE_PROFILE_LOADED:Fire(badgeProfile);

	badgeProfile
		:OnBadgeAwarded(function(badgeId)
			if SETTINGS.isNotificationsDisabled then return end;
			
			Remote_Notification:FireClient(
				player,
				GetNotificationData(badgeId)
			)
		end)

	return badgeProfile;
end

function BadgeService3:FindFirstProfile(player)
	assert(
		typeof(player) == "Instance" and player:IsA("Player"),
		"Invalid :FindFirstProfile parameter."
	)
	if player.Parent ~= Players then return end

	return BADGE_PROFILES[player]
end

function BadgeService3:WaitForProfile(player)
	assert(
		typeof(player) == "Instance" and player:IsA("Player"),
		"Invalid :WaitForProfile parameter."
	)

	if player.Parent ~= Players then return end;
	if BADGE_PROFILES[player] then return BADGE_PROFILES[player] end;

	while true do
		local badgeProfile = ON_BADGE_PROFILE_LOADED:Wait();
		if badgeProfile._player == player then
			return badgeProfile;
		end
		
		if player.Parent ~= Players then return end;
	end
end

function BadgeService3:GetBadgeCount()
	local badgeAmount = 0;
	for _ in pairs(Badges) do
		badgeAmount += 1;
	end
	return badgeAmount;
end

function BadgeService3:GetBadges()
	return Badges, self:GetBadgeCount()
end

function BadgeService3:SetGlobalSettings(changedSettings)
	for index, value in pairs(changedSettings) do
		if typeof(value) == typeof(SETTINGS[index]) then
			SETTINGS[index] = value;
		end
	end
end



function BadgeProfile:AwardBadge(badgeId)
	assert(
		Badges[badgeId],
		("%s is not a valid BadgeID, are you sure you typed it correctly?"):format(badgeId)
	)

	if self._player.Parent ~= Players then return end;

	ConvertTrueDictionaryToArray(self);

	if not table.find(self.Data, badgeId) then
		table.insert(
			self.Data,
			badgeId
		)
		self.OnUpdate:Fire(
			ShallowCopy(self.Data)
		);
		self.OnBadgeAwarded:Fire(badgeId);
	end
end

function BadgeProfile:RemoveBadge(badgeId)
	assert(
		Badges[badgeId],
		("%s is not a valid BadgeID, are you sure you typed it correctly?"):format(badgeId)
	)

	if self._player.Parent ~= Players then return end;

	ConvertTrueDictionaryToArray(self);

	local badgeIndex = table.find(self.Data, badgeId)
	if badgeIndex then
		table.remove(
			self.Data,
			badgeIndex
		)

		self.OnUpdate:Fire(
			ShallowCopy(self.Data)
		)
	end
end

function BadgeProfile:OwnsBadge(badgeId)
	assert(
		Badges[badgeId],
		("%s is not a valid BadgeID, are you sure you typed it correctly?"):format(badgeId)
	)

	ConvertTrueDictionaryToArray(self);

	if table.find(self.Data, badgeId) then
		return true;
	else
		return false;
	end
end

function BadgeProfile:GetOwnedBadges()
	ConvertTrueDictionaryToArray(self);
	
	return ShallowCopy(self.Data);
end

function BadgeProfile:Destroy()
	BADGE_PROFILES[self._player] = nil;
	self.OnUpdate:Destroy()
	self.OnBadgeAwarded:Destroy()
end
BadgeProfile.Remove = BadgeProfile.Destroy

function BadgeProfile:Optimize()
	--\\ Only here for older code to work. Won't do anything. (as it's not needed!)
end

Players.PlayerRemoving:Connect(function(player)
	RunService.Heartbeat:Wait()
	--\\ Allow other PlayerRemoving events to run first;
	
	local badgeProfile = BADGE_PROFILES[player]
	if not badgeProfile then return end;
	
	badgeProfile:Destroy()
end)

return BadgeService3;
