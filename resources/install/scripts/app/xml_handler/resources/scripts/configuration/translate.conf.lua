--	xml_handler.lua
--	Part of FusionPBX
--	Copyright (C) 2017 Mark J Crane <markjcrane@fusionpbx.com>
--	All rights reserved.
--
--	Redistribution and use in source and binary forms, with or without
--	modification, are permitted provided that the following conditions are met:
--
--	1. Redistributions of source code must retain the above copyright notice,
--	   this list of conditions and the following disclaimer.
--
--	2. Redistributions in binary form must reproduce the above copyright
--	   notice, this list of conditions and the following disclaimer in the
--	   documentation and/or other materials provided with the distribution.
--
--	THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
--	INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
--	AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
--	AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
--	OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
--	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
--	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
--	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
--	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
--	POSSIBILITY OF SUCH DAMAGE.

--get the cache
	local cache = require "resources.functions.cache"
	local translate_cache_key = "configuration:translate.conf"
	XML_STRING, err = cache.get(translate_cache_key)

--set the cache
	if not XML_STRING then
		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] " .. translate_cache_key .. " can not be get from memcache: " .. tostring(err) .. "\n");
			end

		--log cache error
			if (debug["cache"]) then
				freeswitch.consoleLog("warning", "[xml_handler] configuration:translate.conf can not be get from memcache: " .. tostring(err) .. "\n");
			end

		--set a default value
			if (expire["translate"] == nil) then
				expire["translate"]= "3600";
			end

		--connect to the database
			local Database = require "resources.functions.database";
			dbh = Database.new('system');

		--include json library
			local json
			if (debug["sql"]) then
				json = require "resources.functions.lunajson"
			end

		--exits the script if we didn't connect properly
			assert(dbh:connected());

		--start the xml array
			local xml = {}
			table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
			table.insert(xml, [[<document type="freeswitch/xml">]]);
			table.insert(xml, [[	<section name="configuration">]]);
			table.insert(xml, [[		<configuration name="translate.conf" description="Number Translation Rules" autogenerated="true">]]);
			table.insert(xml, [[			<profiles>]]);

		--run the query
			sql = "select * from v_number_translations ";
			sql = sql .. "order by number_translation_name asc ";
			if (debug["sql"]) then
				freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
			end
			x = 0;
			dbh:query(sql, function(row)

				--list open tag
					table.insert(xml, [[				<profile name="]]..row.number_translation_name..[[" description="]]..row.number_translation_description..[[">]]);

				--get the nodes
					sql = "select * from v_number_translation_details ";
					sql = sql .. "where number_translation_uuid = :number_translation_uuid ";
					sql = sql .. "order by number_translation_detail_order asc ";
					local params = {number_translation_uuid = row.number_translation_uuid}
					if (debug["sql"]) then
						freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
					end
					x = 0;
					dbh:query(sql, params, function(field)
						if (string.len(field.number_translation_detail_regex) > 0) then
							table.insert(xml, [[					<rule regex="]] .. field.number_translation_detail_regex .. [[" replace="]] .. field.number_translation_detail_replace .. [[" />]]);
						end
					end)

				--list close tag
					table.insert(xml, [[				</profile>]]);

			end)

		--close the extension tag if it was left open
			table.insert(xml, [[			</profiles>]]);
			table.insert(xml, [[		</configuration>]]);
			table.insert(xml, [[	</section>]]);
			table.insert(xml, [[</document>]]);
			XML_STRING = table.concat(xml, "\n");
			if (debug["xml_string"]) then
				freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: " .. XML_STRING .. "\n");
			end

		--close the database connection
			dbh:release();

		--set the cache
			local ok, err = cache.set(translate_cache_key, XML_STRING, expire["translate"]);
			if debug["cache"] then
				if ok then
					freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " stored in memcache\n");
				else
					freeswitch.consoleLog("warning", "[xml_handler] " .. translate_cache_key .. " can not be stored in memcache: " .. tostring(err) .. "\n");
				end
			end

		--send the xml to the console
			if (debug["xml_string"]) then
				local file = assert(io.open(temp_dir .. "/translate.conf.xml", "w"));
				file:write(XML_STRING);
				file:close();
			end

		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " source: database\n");
			end
	else
		--send to the console
			if (debug["cache"]) then
				freeswitch.consoleLog("notice", "[xml_handler] " .. translate_cache_key .. " source: memcache\n");
			end
	end --if XML_STRING
