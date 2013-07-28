/*
	Easy Dialogs by Emmet_

    This Source Code Form is subject to the terms of the Mozilla Public
 	License, v. 2.0. If a copy of the MPL was not distributed with this
 	file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/

#include <a_samp>

#define Dialog:%0(%1,%2,%3,%4) \
	forward dialog_%0(%1,%2,%3,%4); public dialog_%0(%1,%2,%3,%4)

#define Show: #dialog_

#if !defined isnull
    #define isnull(%1) ((!(%1[0])) || (((%1[0]) == '\1') && (!(%1[1]))))
#endif

new stock g_DialogShown[MAX_PLAYERS char];
new stock g_CurrentDialog[MAX_PLAYERS][32 char];

stock ShowDialog(playerid, dialog[], style, caption[], info[], button1[], button2[])
{
	if (funcidx(dialog) != -1)
	{
		g_DialogShown{playerid} = 1;
		strpack(g_CurrentDialog[playerid], dialog);
		ShowPlayerDialog(playerid, 0, style, caption, info, button1, button2);
		return 1;
	}
	return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if (g_DialogShown{playerid} == 1)
	{
	    new unpacked[32];
	    strunpack(unpacked, g_CurrentDialog[playerid]);
		if (funcidx(unpacked) != -1)
		{
		    g_DialogShown{playerid} = 0;
			if (isnull(inputtext))
			{
			    CallLocalFunction(unpacked, "ddds", playerid, response, listitem, "\1");
			    return 1;
			}
		    CallLocalFunction(unpacked, "ddds", playerid, response, listitem, inputtext);
		    return 1;
		}
	}
	if (isnull(inputtext)) return CallLocalFunction("easyDialog_OnDialogResponse", "iiiis", playerid, dialogid, response, listitem, "\1");
    return CallLocalFunction("easyDialog_OnDialogResponse", "iiiis", playerid, dialogid, response, listitem, inputtext);
}

#if defined _ALS_OnDialogResponse
	#undef OnDialogResponse
#else
	#define _ALS_OnDialogResponse
#endif
#define OnDialogResponse easyDialog_OnDialogResponse
forward easyDialog_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]);
