mbc_genvar={
	function()					--NIL
		return nil,0
	end,
	function(c,p,self)			--VAR
		return self:getvar(c[p],c[p+1]),2
	end,
	function()					--TABLE
		return {},0
	end,
	function()			--FUNCTION
	end,
	function(c,p)			--NUMBER
		return c[p]+c[p+1]*256+(c[p+2]+c[p+3]*256)/65536,4
	end,
	function(c,p)			--STRING
		local ss=""
		for i=p,#c do
			local l=c[i]
			if l==0 then return ss,i-p+1
			else ss=ss .. ascii_tochar(l) end
		end
	end,
	function()			--FALSE BOOLEAN
		return false,0
	end,
	function()			--TRUE BOOLEAN
		return true,0
	end,
	function(c,p)			--BYTE
		return c[p],1
	end,
	function(c,p)			--INTERGER
		return c[p]+c[p+1]*256,2
	end,
	function(c,p,self)		--TABLEREF
		return self[c[p]],1
	end
}


mbc_runner=cwi:new{}

function mbc_runner:init()
	self.code,self.var={},{}
	for i=0,255 do
		self.var[i]={}
	end
	self.var[253]=self
end

function mbc_runner:access(t,id)
	
end

function mbc_runner:getkey(t,id)
	if t==0 then					--block variables
		return t,self.boff+id
	elseif t==254 then
		local v=self.var[t][id]
		return self:getkey(tonumber(sub(v,1,3)),tonumber(sub(v,4,6)))
	elseif id>9 and id<100 then
		for k,v in pairs(self.var[t]) do
			if sub(k,#k-1,#k)==id then return t,k end
		end
	end
	return t,id
end

function mbc_runner:getvar(t,id)
	t,id=self:getkey(t,id)
	return self.var[t][id]
end

function mbc_runner:compile(c,p,l)
	self.code[c]={}
	for i=0,l-1 do
		add(self.code[c],peek(p+i))
	end
end

function mbc_runner:run(c)
	c,self.boff,self.bptr=self.code[c],0,{}
	local p,jmp,vt,vks,vv,p1,p2,p3=1,{}

	local function _gv(p,t)
		local ad=0
		if not t then
			t=p
			ad=1
		end
		if mbc_genvar[t] then
			local r1,r2=mbc_genvar[t](c,p+ad,self)
			return r1,r2+ad
		else error("no variable type #" .. t .. "; byte #" .. p) end
	end
	local _c1={ 			--a subset of commands for VAR
		function()		--SET
			return vv
		end,
		function()		--ADD
			return vt[vks]+vv
		end,
		function()		--SUB
			return vt[vks]-vv
		end,
		function()		--MUL
			return vt[vks]*vv
		end,
		function()		--DIV
			return vt[vks]/vv
		end,
		function()		--CONCAT
			return vt[vks] .. tostr(vv)
		end,
		function()		--IFEQUAL
			return vt[vks]==vv
		end,
		function()		--IFLESS
			return vt[vks]<vv
		end,
		function()
			return vt[vks]<=vv
		end,
		function()		--IFFALSE
			return vt[vks]==false
		end,
		function()		--SETTABLE
			vt=vv
			return vt[vks]
		end
	}
	local _c={							--all code commands
		function(self) 					--VAR
			local ad
			vv,ad=_gv(p+4)
			vt,vks=self:getkey(c[p1],c[p2])
			if _c1[c[p3]] then t[ks]=_c1[c[p3]]()
			else error("unknown operation #" .. c[p3] .. " for opcode var; byte #" .. p) end
			return ad+3
		end,
		--function(self)					--LUANAME
		--	local s,ad=_gv(p+3,5)
		--	local vt,vks=self:getkey(c[p1],c[p2])
		--	self.var[vt][vks]=s .. "_" .. vks
		--	return ad+2
		--end,
		function(self)					--FUNC
			self.var[c[p3]]=self:getvar(c[p1],c[p2])(tbl_iunpack(self.var[255]))
			return 4
		end,
		function()						--IF
			if self:getvar(c[p1],c[p2]) then p=_gv(p3,9)
			else p=_gv(p+5,9) end
			return 6
		end,
		function()				--BLOCKSTART
			local v=_gv(p1,8)
			add(self.bptr,v)
			self.boff+=v
			return 1
		end,
		function()				--BLOCKEND
			self.boff-=self.bptr[#self.bptr]
			self.bptr[#self.bptr]=nil
			return 0
		end,
		function()				--BLOCKFORWARD
			local v=_gv(p1,8)
			self.boff+=self.bptr[#self.bptr-v]
			return 1
		end,
		function()				--BLOCKBACK
			local v=_gv(p1,8)
			self.boff-=self.bptr[#self.bptr-v]
			return 1
		end,
		function()				--JUMPSTORE
			add(jmp,p1)
			return 0
		end,
		function()				--JUMPBACK
			if #jmp==0 then error("nothing to jump back to!; byte #" .. p) end
			p=self.jmp[#jmp]
			jmp[#jmp]=nil
			return 0
		end,
		function(self)				--JUMPTO
			p=_gv(p1,9)
			return 2
		end
		--function()					--DEBUGPRINT
		--	local t,id=self:getkey(c[p1],c[p2])
		--	printh("table #" t .. " key["  .. id .. "]=" .. tostr(_gv(p1,1)))
		--	return 2
		--end
	}

	while p<=#c do
		p1,p2,p3=p+1,p+2,p+3
		local t=self.var[c[p+1]]
		if c[p]~=0 and _c[c[p]] then
			local ad=_c[c[p]](self)
			p+=ad+1
		else error("unknown opcode #" .. c[p] .. "; byte #" .. p) end
	end
end