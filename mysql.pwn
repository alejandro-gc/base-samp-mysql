/*	

	MySQL R8 - Example Account Script
	
	by: VincentDunn
	
*/

#include <a_samp>
#include <a_mysql>
#include <easydialog>

//-----------------------------------------------------

#define		MAX_LOG_TRIES		(4)
#define		MAX_PASS_LENGTH		(40)
#define		SALT_LENGTH			(30)

#define     NEWB_SKIN			(299) // claude's skin

/* MySQL Credentials */
#define 	SQL_HOST 			"localhost"
#define 	SQL_USER 			"root"
#define 	SQL_PASS 			"r3070968"
#define 	SQL_DB 	 			"test"

/* Used for position arrays */
#define		posArr{%0}		%0[0], %0[1], %0[2]   
#define		posArrEx{%0}	%0[0], %0[1], %0[2], %0[3]

//-----------------------------------------------------

native WP_Hash(buffer[], len, const str[]);

//-----------------------------------------------------

/* Credits to RyDeR` */
stock randomString(strDest[], strLen = 30)
{
    while(strLen--)
        strDest[strLen] = random(2) ? (random(26) + (random(2) ? 'a' : 'A')) : (random(10) + '0');
}

//-----------------------------------------------------

static Float:g_newbSpawn[4] = {1815.2614,-1369.6233,15.0781,270.4365};

enum e_pInfo
{
	pSQLid,
	pPass[129],
	pSalt[30],
    Float:pHealth,
	Float:pPos[4],
	pInterior,
	pVirtualWorld,
	pSkin
}

new 
	g_PlayerInfo[MAX_PLAYERS][e_pInfo],
	g_Logged[MAX_PLAYERS],
	g_LogTries[MAX_PLAYERS],
	g_Died[MAX_PLAYERS],
	g_Handle;

//-----------------------------------------------------

main(){
}

//-----------------------------------------------------

public OnGameModeInit()
{	
	SetGameModeText("MySQL R-7 Gamemode");
	UsePlayerPedAnims();
	DisableInteriorEnterExits();
	
	mySQL_init();
	TextDraws_Init();
    return 1;
}

public OnGameModeExit()
{
	mysql_close(g_Handle); 
    return 1;
}

//-----------------------------------------------------

stock mySQL_init()
{
	mysql_debug(1); 
	g_Handle = mysql_connect(SQL_HOST, SQL_USER, SQL_DB, SQL_PASS);
	
	/* Table Structure - kind of messy, I know. */
	mysql_function_query(g_Handle, "CREATE TABLE IF NOT EXISTS `users` ( \
		`id` int(11) NOT NULL AUTO_INCREMENT, \
		`name` varchar(24) NOT NULL, \
		`pass` varchar(129) NOT NULL, \
		`salt` varchar(30) NOT NULL, \
		`health` float NOT NULL, \
		`X` float NOT NULL, \
		`Y` float NOT NULL, \
		`Z` float NOT NULL, \
		`A` float NOT NULL, \
		`interior` int(2) NOT NULL, \
		`vw` int(11) NOT NULL, \
		`skin` int(3) NOT NULL, \
		PRIMARY KEY (`id`) \
	)", false, "SendQuery", "");

	return 1;
}

forward SendQuery();
public SendQuery()
{
	// callback for queries that don't fetch data
	return 1;
}

//-----------------------------------------------------

public OnPlayerConnect(playerid)
{
	ToggleMainMenu(playerid, 1);
	SetTimerEx("SafeOnPlayerConnect", 250, 0, "d", playerid);
    return 1;
}

forward SafeOnPlayerConnect(playerid);
public SafeOnPlayerConnect(playerid)
{
	g_Logged[playerid] = 255;
	g_LogTries[playerid] = 0;
	g_Died[playerid] = 0;
	
	SetSpawnInfo(playerid, 0, NEWB_SKIN, posArr{g_newbSpawn}-4.0, 0.0, 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	
	ToggleMainMenu(playerid, 1);
	CheckAccount(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SaveAccount(playerid);
	return 1;
}

public OnPlayerSpawn(playerid)
{	
	if(g_Logged[playerid] == 255) {
		g_Logged[playerid] = 0;
		clearScreen(playerid);
		
		SetPlayerCameraPos(playerid, posArr{g_newbSpawn});
		SetPlayerCameraLookAt(playerid, posArr{g_newbSpawn});
	}
	
	if(g_Died[playerid]) {
		SetCameraBehindPlayer(playerid);
		SetPlayerPos(playerid, posArr{g_newbSpawn});
		SetPlayerFacingAngle(playerid, g_newbSpawn[3]);
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	g_Died[playerid] = 1;
	return 1;
}
//-----------------------------------------------------

stock CheckAccount(playerid)
{
	new query[82];
	
	format(query, sizeof(query), "SELECT id, pass, salt FROM `users` WHERE `name` = '%s' LIMIT 1", returnName(playerid));
	mysql_function_query(g_Handle, query, true, "OnAccountCheck", "d", playerid);
	return 1;
}

forward OnAccountCheck(playerid);
public OnAccountCheck(playerid)
{
	if(playerid != INVALID_PLAYER_ID) { // if the player is still connected
	
		new rows, fields;
		cache_get_data(rows, fields, g_Handle); 
		
		if(rows) {
			g_PlayerInfo[playerid][pSQLid] = cache_get_row_int(0, 0, g_Handle);

			cache_get_row(0, 1, g_PlayerInfo[playerid][pPass], g_Handle, 130); // whirlpool length + 1
			cache_get_row(0, 2, g_PlayerInfo[playerid][pSalt], g_Handle, SALT_LENGTH+1);
			
			ShowDialog(playerid, Show:Login, DIALOG_STYLE_PASSWORD, "{1564F5}Login", "Type in your password below to log in.", "Okay", "Cancel");
		}
		
		else {
			ShowDialog(playerid, Show:Register, DIALOG_STYLE_PASSWORD, "{1564F5}Register", "Type in a password below to register an account.", "Okay", "Cancel");
		}
	}
	return 1;
}

//-----------------------------------------------------

Dialog:Login(playerid, response, listitem, inputtext[])
{
	if(!response || !strlen(inputtext)) {
		return ShowDialog(playerid, Show:Login, DIALOG_STYLE_PASSWORD, "{1564F5}Login", "Type in your password below to log in.", "Okay", "Cancel");
	}
	
	new 
		hashedinput[129];
	
	format(hashedinput, sizeof(hashedinput), "%s%s", g_PlayerInfo[playerid][pSalt], escape(inputtext));
	WP_Hash(hashedinput, 129, hashedinput);
	
	if(strcmp(hashedinput, g_PlayerInfo[playerid][pPass])) {
		g_LogTries[playerid]++;
		
		if(g_LogTries[playerid] == MAX_LOG_TRIES) {
			return SendClientMessage(playerid, -1, "SERVER: Too many login attempts."), Kick(playerid);
		}
		
		SendClientMessage(playerid, -1, "SERVER: Invalid password!"),
		ShowDialog(playerid, Show:Login, DIALOG_STYLE_PASSWORD, "{1564F5}Login", "Type in your password below to log in.", "Okay", "Cancel");
	}
	else {
		LoadAccount(playerid);
	}
	return 1;
}

stock LoadAccount(playerid)
{
	new query[128];
	
	format(query, sizeof(query), "SELECT * FROM `users` WHERE `id` = %d", g_PlayerInfo[playerid][pSQLid]);
	mysql_function_query(g_Handle, query, true, "OnAccountLoad", "d", playerid);
}

forward OnAccountLoad(playerid);
public OnAccountLoad(playerid)
{
	ToggleMainMenu(playerid, 0);
	SetCameraBehindPlayer(playerid);
	
	new temp[40];
	format(temp, sizeof(temp), "SERVER: Welcome %s", returnNameEx(playerid));
	SendClientMessage(playerid, -1, temp);

	
	g_PlayerInfo[playerid][pHealth]         = cache_get_row_float(0, 4, g_Handle),
	g_PlayerInfo[playerid][pPos][0]         = cache_get_row_float(0, 5, g_Handle),
	g_PlayerInfo[playerid][pPos][1]         = cache_get_row_float(0, 6, g_Handle),
	g_PlayerInfo[playerid][pPos][2]         = cache_get_row_float(0, 7, g_Handle),
	g_PlayerInfo[playerid][pPos][3]         = cache_get_row_float(0, 8, g_Handle),
	g_PlayerInfo[playerid][pInterior]       = cache_get_row_int(0, 9, g_Handle),
	g_PlayerInfo[playerid][pVirtualWorld]   = cache_get_row_int(0, 10, g_Handle),
	g_PlayerInfo[playerid][pSkin]           = cache_get_row_int(0, 11, g_Handle);
	
	SetPlayerHealth(playerid, g_PlayerInfo[playerid][pHealth]);	
	SetPlayerPos(playerid, posArr{g_PlayerInfo[playerid][pPos]});
	SetPlayerFacingAngle(playerid, g_PlayerInfo[playerid][pPos][3]);
	SetPlayerInterior(playerid, g_PlayerInfo[playerid][pInterior]);
	SetPlayerVirtualWorld(playerid, g_PlayerInfo[playerid][pVirtualWorld]);
	SetPlayerSkin(playerid, g_PlayerInfo[playerid][pSkin]);
	return 1;
}

//-----------------------------------------------------

Dialog:Register(playerid, response, listitem, inputtext[]) 
{
	if(!response) {
		return SendClientMessage(playerid, -1, "SERVER: You have left the server."), Kick(playerid);
	}
	
	if(isnull(inputtext)) {
		return ShowDialog(playerid, Show:Register, DIALOG_STYLE_PASSWORD, "{1564F5}Register", "Type in a password below to register an account.", "Okay", "Cancel");
	}
	
	if(strlen(inputtext) >= MAX_PASS_LENGTH) {
		return SendClientMessage(playerid, -1, "SERVER: Password must not be more than 40 characters"), ShowDialog(playerid, Show:Register, DIALOG_STYLE_PASSWORD, "{1564F5}Register", "Type in a password below to register an account.", "Okay", "Cancel");
	}
	
	new 
		Salt[30],
		hash[129];
	
	randomString(Salt, SALT_LENGTH);
	format(hash, sizeof(hash), "%s%s", Salt, escape(inputtext));
	
	WP_Hash(hash, sizeof(hash), hash);
	CreateAccount(playerid, Salt, hash);
	
	format(hash, sizeof(hash), "SERVER: Welcome %s", returnNameEx(playerid));
	SendClientMessage(playerid, -1, hash);
	
	g_PlayerInfo[playerid][pSkin] = NEWB_SKIN;
	
	ToggleMainMenu(playerid, 0);
	SetCameraBehindPlayer(playerid);
	SetPlayerPos(playerid, posArr{g_newbSpawn});
	SetPlayerFacingAngle(playerid, g_newbSpawn[3]);
	SetPlayerSkin(playerid, NEWB_SKIN);	
	return 1;
}

//-----------------------------------------------------

stock CreateAccount(playerid, salt[], pass[129])
{
	new query[240];
	format(query, sizeof(query), "INSERT INTO `users` (name, salt, pass) VALUES (\'%s\', \'%s\', \'%s\')",
		returnName(playerid),
		salt,
		pass
	);
	
	mysql_function_query(g_Handle, query, false, "OnAccountCreate", "d", playerid);
}

forward OnAccountCreate(playerid);
public OnAccountCreate(playerid)
{
	g_PlayerInfo[playerid][pSQLid] = mysql_insert_id();
	return 1;
}

stock SaveAccount(playerid)
{
	new 
		query[300],
		Float:pos[4],
		Float:health;
	
	GetPlayerPos(playerid, posArr{pos});
	GetPlayerFacingAngle(playerid, pos[3]);
	GetPlayerHealth(playerid, health);
	
	format(query, sizeof(query), "UPDATE `users` SET health = %.1f, X = %.2f, Y = %.2f, Z = %.2f, A = %.2f, interior = %d, vw = %d, skin = %d WHERE `id` = %d",
		health,
		posArrEx{pos},
		GetPlayerInterior(playerid),
		GetPlayerVirtualWorld(playerid),
		GetPlayerSkin(playerid),
		g_PlayerInfo[playerid][pSQLid]
	);
	
	mysql_function_query(g_Handle, query, false, "SendQuery", "");
	return 1;
}

//-----------------------------------------------------

stock returnName(playerid)
{
	new name[24];
	GetPlayerName(playerid, name, 24);
	return name;
}

stock returnNameEx(playerid)
{
	new name[24];
	GetPlayerName(playerid, name, 24);
	
	for(new x=0; x<24; x++) {
		if(name[x] == '_') {
			name[x] = ' ';
		}
	}

	return name;
}

stock clearScreen(playerid)
{
	for(new i; i<50; i++) {
		SendClientMessage(playerid, -1, "");
	}
	return 1;
}

stock escape(string[])
{
	new esc_string[512];

	mysql_real_escape_string(string, esc_string, g_Handle, sizeof(esc_string));
	return esc_string;
}

//-----------------------------------------------------

new
	Text:MainMenu[4];

stock TextDraws_Init()
{	
	/* Bottom Bar */
	MainMenu[0] = TextDrawCreate(250.000000, 343.000000, "~n~~n~~n~~n~~n~~n~");
	TextDrawAlignment(MainMenu[0], 2);
	TextDrawBackgroundColor(MainMenu[0], 255);
	TextDrawFont(MainMenu[0], 1);
	TextDrawLetterSize(MainMenu[0], 1.000000, 2.000000);
	TextDrawColor(MainMenu[0], -16776961);
	TextDrawSetOutline(MainMenu[0], 1);
	TextDrawSetProportional(MainMenu[0], 1);
	TextDrawUseBox(MainMenu[0], 1);
	TextDrawBoxColor(MainMenu[0], 255);
	TextDrawTextSize(MainMenu[0], 90.000000, 803.000000);

	/* Top Bar */
	MainMenu[1] = TextDrawCreate(250.000000, -12.000000, "~n~~n~~n~~n~~n~~n~");
	TextDrawAlignment(MainMenu[1], 2);
	TextDrawBackgroundColor(MainMenu[1], 255);
	TextDrawFont(MainMenu[1], 1);
	TextDrawLetterSize(MainMenu[1], 1.000000, 2.000000);
	TextDrawColor(MainMenu[1], -16776961);
	TextDrawSetOutline(MainMenu[1], 1);
	TextDrawSetProportional(MainMenu[1], 1);
	TextDrawUseBox(MainMenu[1], 1);
	TextDrawBoxColor(MainMenu[1], 255);
	TextDrawTextSize(MainMenu[1], 90.000000, 918.000000);

	/* Top Colored Bar */
	MainMenu[2] = TextDrawCreate(729.000000, 99.000000, "_");
	TextDrawBackgroundColor(MainMenu[2], 255);
	TextDrawFont(MainMenu[2], 1);
	TextDrawLetterSize(MainMenu[2], 50.000000, 0.099999);
	TextDrawColor(MainMenu[2], -16776961);
	TextDrawSetOutline(MainMenu[2], 0);
	TextDrawSetProportional(MainMenu[2], 1);
	TextDrawSetShadow(MainMenu[2], 1);
	TextDrawUseBox(MainMenu[2], 1);
	TextDrawBoxColor(MainMenu[2], 0x1564F5FF);
	TextDrawTextSize(MainMenu[2], -5.000000, 1031.000000);

	/* Bottom Colored Bar */
	MainMenu[3] = TextDrawCreate(729.000000, 340.000000, "_");
	TextDrawBackgroundColor(MainMenu[3], 255);
	TextDrawFont(MainMenu[3], 1);
	TextDrawLetterSize(MainMenu[3], 50.000000, 0.099999);
	TextDrawColor(MainMenu[3], -16776961);
	TextDrawSetOutline(MainMenu[3], 0);
	TextDrawSetProportional(MainMenu[3], 1);
	TextDrawSetShadow(MainMenu[3], 1);
	TextDrawUseBox(MainMenu[3], 1);
	TextDrawBoxColor(MainMenu[3], 0x1564F5FF);
	TextDrawTextSize(MainMenu[3], -5.000000, 1031.000000);
	return 1;
}

stock ToggleMainMenu(playerid, toggle)
{
	for(new i=0; i<sizeof(MainMenu); i++) {
		if(toggle) {
			TextDrawShowForPlayer(playerid, MainMenu[i]);
			TogglePlayerControllable(playerid, 0);
		}
		
		else {
			TextDrawHideForPlayer(playerid, MainMenu[i]);
			TogglePlayerControllable(playerid, 1);
		}
	}
	return 1;
}
