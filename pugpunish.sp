#include <sourcemod>
#include <pugsetup>
#include <sdkhooks>
#include <redirect_core>

#define SERVER 0

Database g_dDatabase = null;

char g_szAuth[MAXPLAYERS + 1][32];
char sip[MAXPLAYERS + 1][32];
char gThisServerIp[32];

int TimeDisconnet[MAXPLAYERS + 1];
int Seconds[MAXPLAYERS + 1];
int esptime[MAXPLAYERS + 1];
int cbtime[MAXPLAYERS + 1];
int LivePlayer[MAXPLAYERS + 1];
int end[MAXPLAYERS + 1];

bool showmenu[MAXPLAYERS + 1];
bool IsMatchEnd;
bool IsPlayer[MAXPLAYERS + 1];
bool IsFristTime[MAXPLAYERS + 1];
bool AskClient[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "PugPunish",
	author = "neko",
	description = "punishment plugin",
	version = "0.14"
};


public void OnPluginStart()
{
	SQL_MakeConnection();
	HookEvent("player_spawn", Event_PlayerSpawn);
	int hostip = FindConVar("hostip").IntValue;
	Format(gThisServerIp, sizeof(gThisServerIp), "%i.%i.%i.%i:%i", hostip >>> 24, hostip >> 16 & 0xFF, hostip >> 8 & 0xFF, hostip & 0xFF, FindConVar("hostport").IntValue);
}

public void OnMapStart()
{
	IsMatchEnd = true;
	CheckServerIssue();
}

void CheckServerIssue()
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "SELECT * FROM `serverissue` WHERE ip = '%s'",gThisServerIp);
	g_dDatabase.Query(SQL_FetchServer_CB, szQuery);
}

public void SQL_FetchServer_CB(Database db, DBResultSet results, const char[] error, any data)
{
	
	if (results.FetchRow())
	{
		return;
	}
	else
	{
		char szQuery[512];
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `serverissue` (`ip`,`isend`,`players`) VALUES ('%s','1','-1')",gThisServerIp);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	}
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	//if(AskClient[iClient])
		//AskReconnectOrKick(iClient);
	
	CreateTimer(1.5,IsInGame,iClient);
	if(!IsMatchEnd)
	{
		CreateTimer(1.5,IsInGame,iClient);
		checkPlayerlive();
	}
	else
		IsPlayer[iClient] = false;
	
}

public Action IsInGame( Handle timer,int client)
{
	if(IsMatchEnd)
		return;
	if(!IsPlayerAlive(client))
		return;
	IsPlayer[client] = true;
	if(IsFristTime[client])
	{
		IsFristTime[client]=!IsFristTime[client];
		PrintToChat(client,"^\x07你已进入比赛! \x04请不要在比赛未结束时随意离开! \x06随意放弃比赛将受到惩罚或者累计不良信用记录!\x01");
		PrintToChat(client,"^\x07你已进入比赛! \x04请不要在比赛未结束时随意离开! \x06随意放弃比赛将受到惩罚或者累计不良信用记录!\x01");
		PrintToChat(client,"^\x07你已进入比赛! \x04请不要在比赛未结束时随意离开! \x06随意放弃比赛将受到惩罚或者累计不良信用记录!\x01");
	}
}

void SQL_MakeConnection()
{
	if (g_dDatabase != null)
		delete g_dDatabase;
	char szError[512];
	g_dDatabase = SQL_Connect("neko", true, szError, sizeof(szError));
	if (g_dDatabase == null)
	{
		SetFailState("Cannot connect to datbase error: %s", szError);
	}
}

public void OnClientPostAdminCheck(int client)
{
	
	if (!GetClientAuthId(client, AuthId_Steam2, g_szAuth[client], sizeof(g_szAuth)))
	{
		KickClient(client, "Verification problem, Please reconnect");
		return;
	}
	if(StrEqual(g_szAuth[client],"")||StrEqual(g_szAuth[client],"BOT"))
		return;
	showmenu[client] = true;
	TimeDisconnet[client] = -1;
	Seconds[client] = 60;
	IsPlayer[client] = false;
	IsFristTime[client] = true;
	AskClient[client] = false;
	
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "SELECT * FROM `puguser` WHERE auth = '%s'",g_szAuth[client]);
	g_dDatabase.Query(SQL_FetchUser_CB, szQuery, GetClientSerial(client));
	
	FormatEx(szQuery, sizeof(szQuery), "SELECT * FROM `puglog` WHERE auth = '%s'",g_szAuth[client]);
	g_dDatabase.Query(SQL_FetchUserLog_CB, szQuery, GetClientSerial(client));
	
}

public void SQL_FetchUser_CB(Database db, DBResultSet results, const char[] error, any data)
{
	checkPlayerlive();
	int iClient = GetClientFromSerial(data);
	
	if (results.FetchRow())
	{
		TimeDisconnet[iClient] = results.FetchInt(1);
		results.FetchString(2, sip[iClient], sizeof(sip));
		CheckIssue(iClient);
	}
	
}

public void SQL_FetchUserLog_CB(Database db, DBResultSet results, const char[] error, any data)
{
	int iClient = GetClientFromSerial(data);
	char szQuery[512];
	if (results.FetchRow())
	{
		esptime[iClient] = results.FetchInt(1);
		cbtime[iClient] = results.FetchInt(2);
		if(esptime[iClient]>0)
			PrintToAdmins("玩家 %N 目前累计逃跑%i次，累计返回 %i次",iClient,esptime[iClient],cbtime[iClient]);
	}
	else
	{
		FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `puglog` (`auth`,`esp`,`cb`) VALUES ('%s','0','0')",g_szAuth[iClient]);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	}
	
}

void CheckIssue(int iClient)
{
	char szQuery[512];
	int now=GetTime();
	if( now - TimeDisconnet[iClient] > 600)
	{
		BanClient(iClient, 30, BANFLAG_AUTO,"因为逃离比赛而冷却","因为逃离比赛而冷却");
		FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `auth` = '%s'", g_szAuth[iClient]);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(iClient));
		return;
	}
	if(StrEqual(sip[iClient],gThisServerIp))
	{
		
		FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `auth` = '%s'", g_szAuth[iClient]);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(iClient));
		FormatEx(szQuery, sizeof(szQuery), "UPDATE `puglog` SET `cb` = '%i' WHERE `auth` = '%s'",cbtime[iClient]+1,g_szAuth[iClient]);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	}
	if(!StrEqual(sip[iClient],gThisServerIp))
	{
		FormatEx(szQuery, sizeof(szQuery), "SELECT * FROM  `serverissue` WHERE ip = '%s'",sip[iClient]);
		g_dDatabase.Query(SQL_FetchMatch_CB, szQuery, GetClientSerial(iClient));
	}
}

public void SQL_FetchMatch_CB(Database db, DBResultSet results, const char[] error, any data)
{
	int iClient = GetClientFromSerial(data);
	if (results.FetchRow())
	{
		LivePlayer[iClient] = results.FetchInt(1);
		end[iClient] = results.FetchInt(2);
		
		if( end[iClient] == 1)
			return;
		if(LivePlayer[iClient] >= 10)
			return
		AskClient[iClient] = true;
		AskReconnectOrKick(iClient);
	}
	else
	LogError("can't find match");
}

public void PugSetup_OnLive()
{
	refreshzt();
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `serverissue` SET  `isend`= '0' WHERE `ip` = '%s'",gThisServerIp);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	IsMatchEnd=false;
	checkPlayerlive();
}

public void PugSetup_OnForceEnd(int client)
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `serverissue` SET `isend` = '1' WHERE `ip` = '%s'",gThisServerIp);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `serverip` = '%s'",gThisServerIp );
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	IsMatchEnd=true;
	refreshzt();
}

public void PugSetup_OnMatchOver(bool hasDemo, const char[] demoFileName)
{
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `serverissue` SET `isend` = '1' WHERE `ip` = '%s'",gThisServerIp);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `serverip` = '%s'", gThisServerIp );
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	IsMatchEnd=true;
	refreshzt();
}

refreshzt()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsValidClient(i))
			IsFristTime[i] = true;
	}
}

AskReconnectOrKick(int client)
{
	if(showmenu[client])
	{
		CreateTimer(1.00, cooldown,client,TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		showmenu[client]=!showmenu[client];
	}
	
	int sec=Seconds[client]%60;
	Menu menu = new Menu(Handler_mianMenu);
	menu.SetTitle("选择时间[00:%i]\n\n玩家须知:",sec);
	menu.AddItem("0","请不要抛弃你的队友",ITEMDRAW_DISABLED);
	menu.AddItem("1","请不要在比赛未结束时离开游戏",ITEMDRAW_DISABLED);
	char buffer[128];
	Format(buffer,128,"返回之前比赛\n[IP:%s]",sip[client]);
	menu.AddItem("2",buffer);
	menu.AddItem("3","我选择放弃比赛接受冷却时间");
	menu.Display(client, MENU_TIME_FOREVER);
	menu.ExitButton = false;
}

public Action cooldown(Handle timer,int client)
{
	AskReconnectOrKick(client);
	Seconds[client]--;
	if(Seconds[client]<=0){
		char szQuery[512];
		KickClient(client,"请先完成之前的比赛");
		FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `auth` = '%s'", g_szAuth[client]);
		g_dDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(client));
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public int Handler_mianMenu(Menu menu, MenuAction action, int client,int itemNum)
{
	
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 2: 
			{
				RedirectClientOnServerEx(client, sip[client]);
			}
			case 3:
			{
				char szQuery[512];
				BanClient(client, 30, BANFLAG_AUTO,"因为逃离比赛而冷却","因为逃离比赛而冷却");
				FormatEx(szQuery, sizeof(szQuery), "DELETE FROM `puguser` WHERE `auth` = '%s'", g_szAuth[client]);
				g_dDatabase.Query(SQL_CheckForErrors, szQuery, GetClientSerial(client));
			}
		}
	}
}

public OnClientDisconnect(int client)
{
	checkPlayerlive();
	
	if(!IsPlayer[client])
		return;
	PrintToChatAll("玩家\x08%N\x01 在比赛中途离开游戏, 在规定时间内若未返回将接受惩罚",client);
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "INSERT INTO `puguser` (`auth`,`serverip`,`time`) VALUES ('%s','%s','%i')",g_szAuth[client],gThisServerIp,GetTime());
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
	
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `puglog` SET `esp` = '%i' WHERE `auth` = '%s'",esptime[client]+1,g_szAuth[client]);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
}

public void SQL_CheckForErrors(Database db, DBResultSet results, const char[] error, any data)
{	
	
	if (!StrEqual(error, ""))
	{
		LogError("Databse error, %s", error);
		return;
	}
}

stock void PrintToAdmins(const char[] msg, any ...)
{
	char buffer[300];
	VFormat(buffer, sizeof(buffer), msg, 2);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(CheckCommandAccess(i, "", ADMFLAG_KICK))
		{
			PrintToChat(i, buffer);
		}
	}
}

void checkPlayerlive()
{
	int num = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsValidClient(i) && GetClientTeam(i) != 1)
			num++;
	}
	
	char szQuery[512];
	FormatEx(szQuery, sizeof(szQuery), "UPDATE `serverissue` SET `players` = '%i' WHERE `ip` = '%s'",num-1,gThisServerIp);
	g_dDatabase.Query(SQL_CheckForErrors, szQuery);
}

stock bool IsValidClient( client )
{
	if ( client < 1 || client > MaxClients ) return false;
	if ( !IsClientConnected( client )) return false;
	if ( !IsClientInGame( client )) return false;
	if ( IsFakeClient(client)) return false;
	return true;
}