-- buyhome <huangqi@rhomobi.com> 20130705 (v0.5.1)
-- License: same to the Lua one
-- TODO: copy the LICENSE file
-------------------------------------------------------------------------------
-- begin of the idea : http://rhomobi.com/topics/
-- http://lua-users.org/wiki/LuaXml
-- load library
local JSON = require 'cjson'
-- local md5 = require 'md5'
package.path = "/usr/local/webserver/lua/lib/?.lua;";
local deflate = require 'compress.deflatelua'
local http = require "resty.http"
-- originality
local error001 = JSON.encode({ ["resultCode"] = 1, ["description"] = "No response because you has inputted airports"});
local error002 = JSON.encode({ ["resultCode"] = 2, ["description"] = "Get Prices from extension is no response"});
function error003 (mes)
	local res = JSON.encode({ ["resultCode"] = 3, ["description"] = mes});
	return res
end
function sleep(n)
   socket.select(nil, nil, n)
end
-- Cloud set.
function urlencode(s) return s and (s:gsub("[^a-zA-Z0-9.~_-]", function (c) return string.format("%%%02x", c:byte()); end)); end
function urldecode(s) return s and (s:gsub("%%(%x%x)", function (c) return char(tonumber(c,16)); end)); end
local function _formencodepart(s)
	return s and (s:gsub("%W", function (c)
		if c ~= " " then
			return format("%%%02x", c:byte());
		else
			return "+";
		end
	end));
end
function formencode(form)
	local result = {};
 	if form[1] then -- Array of ordered { name, value }
 		for _, field in ipairs(form) do
 			-- t_insert(result, _formencodepart(field.name).."=".._formencodepart(field.value));
			table.insert(result, field.name .. "=" .. tostring(field.value));
 		end
 	else -- Unordered map of name -> value
 		for name, value in pairs(form) do
 			-- table.insert(result, _formencodepart(name).."=".._formencodepart(value));
			table.insert(result, name .. "=" .. tostring(value));
 		end
 	end
 	return table.concat(result, "&");
end
function parseargs(s)
  local arg = {}
  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end
function collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with "..label)
      end
      if toclose.label ~= label then
        error("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[#stack], text)
  end
  if #stack > 1 then
    error("unclosed "..stack[#stack].label)
  end
  return stack[1]
end
-- local ak = "8fed80908d9683600e1d30f2a64006f2"
-- local sk = "8047E3D8b60e2887d1d866b4b12028c6"
if ngx.var.request_method == "GET" then
	-- local FlightLineID = ngx.var.fltid;
	local org = string.sub(ngx.var.city, 1, 3);
	local dst = string.sub(ngx.var.city, 4, 6);
	local tkey = ngx.var.date;
	-- local prisrc = ngx.var.source;
	local reqtype = ngx.var.type;
	-- init the DICT.
	local port = ngx.shared.airport;
	local porg = port:get(string.upper(org));
	local pdst = port:get(string.upper(dst));
	local city = ngx.shared.citycod;
	local torg = city:get(string.upper(org));
	local tdst = city:get(string.upper(dst));
	if porg or pdst then
		ngx.print(error001);
	else
		-- init key from ctrip base on sina
		function fatchkey (exProxy)
			local sinaurl = "http://yougola.sinaapp.com/";
			local md5uri = "fatchkey/";
			-- local sinakey = "5P826n55x3LkwK5k88S5b3XS4h30bTRg";
			-- print("--------------")
			-- print(sinaurl .. md5uri);
			-- print("--------------")
			-- init response table
			-- local respsina = {};
			-- local body, code, headers = http.request(baseurl .. md5uri)
			local hc = http:new()
			local ok, code, headers, status, body  = hc:request {
			-- local body, code, headers, status = http.request {
			-- local ok, code, headers, status, body = http.request {
				-- url = "http://cloudavh.com/data-gw/index.php",
				url = sinaurl .. md5uri,
				proxy = exProxy,
				-- proxy = "http://10.123.74.137:808",
				-- proxy = "http://" .. tostring(arg[2]),
				timeout = 5000,
				method = "GET", -- POST or GET
				-- add post content-type and cookie
				headers = {
					["Host"] = "yougola.sinaapp.com",
					-- ["SOAPAction"] = "http://ctrip.com/Request",
					["Cache-Control"] = "no-cache",
					-- ["Auth-Timestamp"] = filet,
					-- ["Auth-Signature"] = md5.sumhexa(sinakey .. filet),
					-- ["Accept-Encoding"] = "gzip",
					-- ["Accept"] = "*/*",
					["Connection"] = "keep-alive",
					-- ["Content-Type"] = "text/xml; charset=utf-8",
					-- ["Content-Length"] = string.len(request)
				},
				-- body = formdata,
				-- source = ltn12.source.string(form_data);
				-- source = ltn12.source.string(request),
				-- sink = ltn12.sink.table(respsina)
			}
			if code == 200 then
				if JSON.decode(body).ret_code == 0 then
					return 200, body
				else
					return 401, body
				end
			else
				return code, JSON.null
			end
		end
		local apikey = ""
		local siteid = ""
		local unicode = ""
		while true do
			local codenum, resbody = fatchkey ()
			if codenum == 200 then
				resbody = JSON.decode(resbody);
				unicode = resbody.aid
				apikey = tostring(resbody.api_key)
				siteid = resbody.sid
				break;
			end
		end
		if torg and tdst then --dom;
			if reqtype ~= "dom" then
				ngx.exit(ngx.HTTP_BAD_REQUEST);
			else
				-- ngx.say("dom");
				local date = string.sub(tkey, 1, 4) .. "-" .. string.sub(tkey, 5, 6) .. "-" .. string.sub(tkey, 7, 8);
				local today = os.date("%Y-%m-%d", os.time());
				local baseurl = "http://openapi.ctrip.com";
				local domuri = "/Flight/DomesticFlight/OTA_FlightSearch.asmx";
				local ts = os.time()
				local sign = string.upper(ngx.md5(ts .. unicode .. string.upper(ngx.md5(apikey)) .. siteid .. "OTA_FlightSearch"))
				local domxml = ([=[
				<Request>
				  <Header>
				    <AllianceID>%s</AllianceID>
				    <SID>%s</SID>
				    <TimeStamp>%s</TimeStamp>
				    <RequestType>OTA_FlightSearch</RequestType>
				    <Signature>%s</Signature>
				  </Header>
				  <FlightSearchRequest>
				    <SearchType>S</SearchType>
				    <BookDate>%s</BookDate>
				    <OrderBy>DepartTime</OrderBy>
				    <Direction>ASC</Direction>
				    <Routes>
				      <FlightRoute>
				        <DepartCity>%s</DepartCity>
				        <ArriveCity>%s</ArriveCity>
				        <DepartDate>%s</DepartDate>
				        <AirlineDibitCode></AirlineDibitCode>
				      </FlightRoute>
				    </Routes>
				  </FlightSearchRequest>
				</Request>]=]):format(unicode, siteid, ts, sign, today, string.upper(org), string.upper(dst), date)
				domxml = string.gsub(domxml, "<", "&lt;")
				-- domxml = string.gsub(domxml, ">", "&gt;")
				-- domxml = string.gsub(domxml, "\n", "")
				local request = ([=[<?xml version='1.0' encoding='UTF-8'?>
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
				<xsd:Request xmlns:xsd="http://ctrip.com/">
				<xsd:requestXML>%s</xsd:requestXML>
				</xsd:Request>
				</soapenv:Body>
				</soapenv:Envelope>]=]):format(domxml)
				local hc = http:new()
				local ok, code, headers, status, body  = hc:request {
				-- local body, code, headers, status = http.request {
				-- local ok, code, headers, status, body = http.request {
					-- url = "http://cloudavh.com/data-gw/index.php",
					url = baseurl .. domuri .. "?WSDL",
					-- proxy = "http://10.123.74.137:808",
					-- proxy = "http://" .. tostring(arg[2]),
					timeout = 30000,
					method = "POST", -- POST or GET
					-- add post content-type and cookie
					-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
					-- headers = { ["Host"] = "flight.itour.cn", ["X-AjaxPro-Method"] = "GetFlight", ["Cache-Control"] = "no-cache", ["Accept-Encoding"] = "gzip,deflate,sdch", ["Accept"] = "*/*", ["Origin"] = "chrome-extension://fdmmgilgnpjigdojojpjoooidkmcomcm", ["Connection"] = "keep-alive", ["Content-Type"] = "application/json", ["Content-Length"] = string.len(JSON.encode(request)), ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.65 Safari/537.36" },
					headers = {
						["Host"] = "openapi.ctrip.com",
						["SOAPAction"] = "http://ctrip.com/Request",
						["Cache-Control"] = "no-cache",
						["Accept-Encoding"] = "gzip",
						["Accept"] = "*/*",
						["Connection"] = "keep-alive",
						["Content-Type"] = "text/xml; charset=utf-8",
						["Content-Length"] = string.len(request)
					},
					-- body = formdata,
					-- source = ltn12.source.string(form_data);
					-- source = ltn12.source.string(request),
					-- sink = ltn12.sink.table(respbody)
					body = request
				}
				if code == 200 then
					-- resxml = deflate.gunzip(resxml)
					-- change to use compress.deflatelua
					local output = {}
					deflate.gunzip {
					  input = body,
					  output = function(byte) output[#output+1] = string.char(byte) end
					}
					resxml = table.concat(output)
					resxml = string.gsub(resxml, "&lt;", "<")
					resxml = string.gsub(resxml, "&gt;", ">")
					ngx.print(resxml);
				else
					ngx.print(error002);
				end
			end
		else
			if reqtype ~= "intl" then
				ngx.exit(ngx.HTTP_BAD_REQUEST);
			else
				-- local org = string.sub(arg[1], 1, 3);
				-- local dst = string.sub(arg[1], 5, 7);
				-- local tkey = string.sub(arg[1], 9, -2);
				-- local expiret = os.time({year=string.sub(tkey, 1, 4), month=tonumber(string.sub(tkey, 5, 6)), day=tonumber(string.sub(tkey, 7, 8)), hour="00"})
				local date = string.sub(tkey, 1, 4) .. "-" .. string.sub(tkey, 5, 6) .. "-" .. string.sub(tkey, 7, 8);
				-- local today = os.date("%Y-%m-%d", os.time());
				local baseurl = "http://openapi.ctrip.com"
				-- local domuri = "/Flight/DomesticFlight/OTA_FlightSearch.asmx"
				local intluri = "/Flight/IntlFlight/OTA_IntlFlightSearch.asmx"
				-- Signature=Md5(TimeStamp+AllianceID+MD5(密钥).ToUpper()+SID+RequestType).ToUpper()
				local ts = os.time()
				-- local ts = "1380250839"
				local sign = string.upper(ngx.md5(ts .. unicode .. string.upper(ngx.md5(apikey)) .. siteid .. "OTA_IntlFlightSearch"))
				-- print("-----------------")
				-- print(ts)
				-- print(sign)
				-- print(string.upper(org), string.upper(dst), date, today)
				-- print("------------------------------------------")
				--[[
				local domxml = ([=[
				<Request>
				  <Header>
				    <AllianceID>%s</AllianceID>
				    <SID>%s</SID>
				    <TimeStamp>%s</TimeStamp>
				    <RequestType>OTA_IntlFlightSearch</RequestType>
				    <Signature>%s</Signature>
				  </Header>
				  <FlightSearchRequest>
				    <SearchType>S</SearchType>
				    <BookDate>%s</BookDate>
				    <OrderBy>DepartTime</OrderBy>
				    <Direction>ASC</Direction>
				    <Routes>
				      <FlightRoute>
				        <DepartCity>%s</DepartCity>
				        <ArriveCity>%s</ArriveCity>
				        <DepartDate>%s</DepartDate>
				        <AirlineDibitCode></AirlineDibitCode>
				      </FlightRoute>
				    </Routes>
				  </FlightSearchRequest>
				</Request>]=]):format(unicode, siteid, ts, sign, today, string.upper(org), string.upper(dst), date)
				domxml = string.gsub(domxml, "<", "&lt;")
				--]]
				-- domxml = string.gsub(domxml, ">", "&gt;")
				-- domxml = string.gsub(domxml, "\n", "")
				local intlxml = ([=[
				<Request>
					<Header>
						<AllianceID>%s</AllianceID>
						<SID>%s</SID>
						<TimeStamp>%s</TimeStamp>
						<RequestType>OTA_IntlFlightSearch</RequestType>
						<Signature>%s</Signature>
					</Header>
					<IntlFlightSearchRequest>
						<TripType>OW</TripType>
						<PassengerType>ADT</PassengerType>
						<PassengerCount>1</PassengerCount>
						<Eligibility>ALL</Eligibility>
						<BusinessType>OWN</BusinessType>
						<ClassGrade>Y</ClassGrade>
						<SalesType>Online</SalesType>
						<FareType>All</FareType>
						<ResultMode>All</ResultMode>
						<OrderBy>Price</OrderBy>
						<Direction>Asc</Direction>
						<SegmentInfos>
							<SegmentInfo>
								<DCode>%s</DCode>
								<ACode>%s</ACode>
								<DDate>%s</DDate>
								<TimePeriod>All</TimePeriod>
							</SegmentInfo>
						</SegmentInfos>
					</IntlFlightSearchRequest>
				</Request>]=]):format(unicode, siteid, ts, sign, string.upper(org), string.upper(dst), date)
				-- domxml = string.gsub(domxml, "<", "&lt;")
				intlxml = string.gsub(intlxml, "<", "&lt;")
				-- soap
				local request = ([=[<?xml version='1.0' encoding='UTF-8'?>
				<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
				<soapenv:Body>
				<xsd:Request xmlns:xsd="http://ctrip.com/">
				<xsd:requestXML>%s</xsd:requestXML>
				</xsd:Request>
				</soapenv:Body>
				</soapenv:Envelope>]=]):format(intlxml)
				-- print(request)
				-- print("-----------------")
				-- init response table
				-- local respbody = {};
				local hc = http:new()
				local ok, code, headers, status, body  = hc:request {
				-- local body, code, headers, status = http.request {
				-- local ok, code, headers, status, body = http.request {
					-- url = "http://cloudavh.com/data-gw/index.php",
					url = baseurl .. intluri .. "?WSDL",
					-- proxy = "http://10.123.74.137:808",
					-- proxy = "http://" .. tostring(arg[2]),
					timeout = 30000,
					method = "POST", -- POST or GET
					-- add post content-type and cookie
					-- headers = { ["Content-Type"] = "application/x-www-form-urlencoded", ["Content-Length"] = string.len(form_data) },
					-- headers = { ["Host"] = "flight.itour.cn", ["X-AjaxPro-Method"] = "GetFlight", ["Cache-Control"] = "no-cache", ["Accept-Encoding"] = "gzip,deflate,sdch", ["Accept"] = "*/*", ["Origin"] = "chrome-extension://fdmmgilgnpjigdojojpjoooidkmcomcm", ["Connection"] = "keep-alive", ["Content-Type"] = "application/json", ["Content-Length"] = string.len(JSON.encode(request)), ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.65 Safari/537.36" },
					headers = {
						["Host"] = "openapi.ctrip.com",
						["SOAPAction"] = "http://ctrip.com/Request",
						["Cache-Control"] = "no-cache",
						["Accept-Encoding"] = "gzip",
						["Accept"] = "*/*",
						["Connection"] = "keep-alive",
						["Content-Type"] = "text/xml; charset=utf-8",
						["Content-Length"] = string.len(request)
					},
					-- body = formdata,
					-- source = ltn12.source.string(form_data);
					-- source = ltn12.source.string(request),
					-- sink = ltn12.sink.table(respbody)
					body = request
				}
				if code == 200 then
					local resxml = "";
					--[[
					local reslen = table.getn(respbody)
					-- print(reslen)
					for i = 1, reslen do
						-- print(respbody[i])
						resxml = resxml .. respbody[i]
					end
					--]]
					-- resxml = deflate.gunzip(resxml)
					-- change to use compress.deflatelua
					local output = {}
					deflate.gunzip {
					  input = body,
					  output = function(byte) output[#output+1] = string.char(byte) end
					}
					resxml = table.concat(output)
					-- resxml = zlib.decompress(resxml)
					resxml = string.gsub(resxml, "&lt;", "<")
					resxml = string.gsub(resxml, "&gt;", ">")
					local idx1 = string.find(resxml, "<ShoppingResults");
					local idx2 = string.find(resxml, "</ShoppingResults>");
					if idx1 ~= nil and idx2 ~= nil then
						local prdata = string.sub(resxml, idx1, idx2+17);
						-- print(prdata)
						local pr_xml = collect(prdata);
						-- init the table
						local rfid = {};
						local imax = {};
						local bigtab = {};
						local union = {};
						for i = 1, table.getn(pr_xml[1]) do
						-- for i = 1, 1 do
							local pritab = {};
							local bunktb = {};
							for x = 1, 1 do
							-- for x = 1, table.getn(pr_xml[1][i][2]) do --Get the PolicyInfo and PolicyInfo's number;
								local idxtab = {};
								local tmppri = {};
								local tbunks = {};
								for y = 1, table.getn(pr_xml[1][i][2][x]) do --each id of the PolicyInfo[x](pr_xml[1][i][2][x])
									if pr_xml[1][i][2][x][y]["label"] ~= "FlightBaseInfos" and pr_xml[1][i][2][x][y]["label"] ~= "PriceInfos" and pr_xml[1][i][2][x][y]["label"] ~= "NoSalesStr" then
										-- print(pr_xml[1][i][2][x][y]["label"], pr_xml[1][i][2][x][y][1])
										idxtab[pr_xml[1][i][2][x][y]["label"]] = pr_xml[1][i][2][x][y][1]
									else
										if pr_xml[1][i][2][x][y]["label"] == "FlightBaseInfos" then
											for z = 1, table.getn(pr_xml[1][i][2][x][y]) do
												local tmpbunk = {};
												for w = 1, table.getn(pr_xml[1][i][2][x][y][z]) do
													-- print(pr_xml[1][i][2][x][y][z][w]["label"], pr_xml[1][i][2][x][y][z][w][1])
													tmpbunk[pr_xml[1][i][2][x][y][z][w]["label"]] = pr_xml[1][i][2][x][y][z][w][1]
												end
												table.insert(tbunks, tmpbunk)
											end		
										end
										if pr_xml[1][i][2][x][y]["label"] == "PriceInfos" then
											for z = 1, table.getn(pr_xml[1][i][2][x][y][1]) do
												-- print(pr_xml[1][i][2][x][y][1][z]["label"], pr_xml[1][i][2][x][y][1][z][1])
												tmppri[pr_xml[1][i][2][x][y][1][z]["label"]] = pr_xml[1][i][2][x][y][1][z][1]
											end
										end
									end
								end
								local priceinfo = {};
								local tmppritab = {};
								priceinfo["priceinfo"] = tmppri;
								-- NoSalesStr
								priceinfo["salelimit"] = idxtab;
								tmppritab["ctrip"] = priceinfo;
								table.insert(pritab, tmppritab)
								table.insert(bunktb, tbunks)
							end
							-- print(JSON.encode(pritab))
							-- print(JSON.encode(bunktb))
							local seginf = {};
							local fid = "";
							local fltscore = "";
							for j = 1, table.getn(pr_xml[1][i][1]) do --Get the FlightInfos and FlightInfos's number
								local tmpfid = "";
								-- /ShoppingResults/ShoppingResultInfo/FlightInfos/FlightsInfo/Flights
								for k = 1, table.getn(pr_xml[1][i][1][j][3]) do
									local tmpseg = {};
									local fltkey = {};
									for l = 1, table.getn(pr_xml[1][i][1][j][3][k]) do
										-- print(pr_xml[1][i][1][j][3][k][l]["label"], pr_xml[1][i][1][j][3][k][l][1])
										tmpseg[pr_xml[1][i][1][j][3][k][l]["label"]] = pr_xml[1][i][1][j][3][k][l][1]
										if pr_xml[1][i][1][j][3][k][l]["label"] == "DPort" then
											fltkey[1] = pr_xml[1][i][1][j][3][k][l][1];
										end
										if pr_xml[1][i][1][j][3][k][l]["label"] == "DTime" then
											fltkey[2] = pr_xml[1][i][1][j][3][k][l][1];
										end
										if pr_xml[1][i][1][j][3][k][l]["label"] == "APort" then
											fltkey[3] = pr_xml[1][i][1][j][3][k][l][1];
										end
										if pr_xml[1][i][1][j][3][k][l]["label"] == "ATime" then
											fltkey[4] = pr_xml[1][i][1][j][3][k][l][1];
										end
									end
									table.insert(seginf, tmpseg);
									if string.len(tmpfid) == 0 then
										tmpfid = fltkey[1] .. fltkey[2] .. "/" .. fltkey[3] .. fltkey[4];
										fltscore = tonumber(fltkey[2]);
									else
										tmpfid = tmpfid .. "-" .. fltkey[1] .. fltkey[2] .. "/" .. fltkey[3] .. fltkey[4];
									end
								end
								if string.len(fid) == 0 then
									fid = tmpfid;
								else
									fid = fid .. "," .. tmpfid;
								end
								tmpfid = "";
							end
							-- print(JSON.encode(seginf))
							-- Caculate FlightLineID
							local FlightLineID = ngx.md5(fid)
							local ctrip = {};
							ctrip["bunks_idx"] = bunktb;
							-- ctrip["limit"] = limtab;
							ctrip["prices_data"] = pritab;
							ctrip["flightline_id"] = FlightLineID;
							ctrip["checksum_seg"] = seginf;
							table.insert(bigtab, ctrip)
						end
						if table.getn(bigtab) > 0 then
							ngx.print(JSON.encode(bigtab))
						else
							ngx.print(error002)
						end
					else
						ngx.print(error002)
					end
				else
					ngx.print(error002)
				end
			end
		end
	end
else
	ngx.exit(ngx.HTTP_FORBIDDEN);
end