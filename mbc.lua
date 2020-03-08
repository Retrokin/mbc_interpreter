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
	function(c,p,self)			--FUNCTION
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


mbc_runner=cwi:new{
	--code={}
}

function mbc_runner:init()
	self.code,self.var={},{}
	for i=0,255 do
		self.var[i]={}
	end
end

function mbc_runner:access(t,id)
	
end

function mbc_runner:getkey(t,id)
	if t==1 then					--block variables
		return self.boff+id
	elseif id>9 and id<100 then
		for k,v in pairs(self.var[t]) do
			if sub(k,#k-1,#k)==id then return k end
		end
	end
	return id
end

function mbc_runner:getvar(t,id)
	return self.var[t][self:getkey(t,id)]
end

function mbc_runner:compile(c,p,l)
	self.code[c]={}
	for i=0,l-1 do
		add(self.code[c],peek(p+i))
	end
end

function mbc_runner:run(c)
	c,self.boff,self.bptr=self.code[c],0,{}
	local p,jmp=1,{}

	local function _gv(p,t)
		if not t then
			t=p
			p+=1
		end
		if mbc_genvar[t] then return mbc_genvar[t](c,p,self)
		else error("no variable type #" .. t .. "; byte #" .. p) end
	end
	local _c1={ 			--a subset of commands for VAR
		function(t,ks,v)		--SET
			t[ks]=v
		end,
		function(t,ks,v)		--ADD
			t[ks]=t[ks]+v
		end,
		function(t,ks,v)		--SUB
			t[ks]=t[ks]-v
		end,
		function(t,ks,v)		--MUL
			t[ks]=t[ks]*v
		end,
		function(t,ks,v)		--DIV
			t[ks]=t[ks]/v
		end,
		function(t,ks,v)		--CONCAT
			t[ks]=t[ks] .. v
		end,
		function(t,ks,v)		--IFEQUAL
			t[ks]=t[ks]==v
		end,
		function(t,ks,v)		--IFLESS
			t[ks]=t[ks]<v
		end,
		function(t,ks,v)		--IFLESSEQUAL
			t[ks]=t[ks]<=v
		end,
		function(t,ks,v)		--SETTABLE
			t=v
		end
	}
	local _c={							--all code commands
		function(self) 					--VAR
			local v,ad=_gv(p+4)
			local t,ks=self.var[c[p+1]],self:getkey(c[p+1],c[p+2])
			if _c1[c[p+3]] then _c1[c[p+3]](t,ks,v)
			else error("unknown operation #" .. c[p+3] .. " for opcode var; byte #" .. p) end
			return ad
		end,
		function(self)					--LUANAME
			local s,ad=_gv(p+3,6)
			t[c[p+2]]=s .. "_" .. c[c[p+2]]
			return ad
		end,
		function(self)					--FUNC
			local t,rk=_gv(p+1,1),self:getkey(c[p+3],c[p+4])
			self.var[c[p+3]][rk](tbl_iunpack(self.var[255]))
			return 4
		end,
		function()						--IF
			if self:getvar(c[p+1],c[p+2]) then p=_gv(p+3,9)
			else p=_gv(p+5,9) end
			return 6
		end,
		function()				--BLOCKSTART
			local v=_gv(p+1,8)
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
			local v=_gv(p+1,8)
			self.boff+=self.bptr[#self.bptr-v]
			return 1
		end,
		function()				--BLOCKBACK
			local v=_gv(p+1,8)
			self.boff-=self.bptr[#self.bptr-v]
			return 1
		end,
		function()				--JUMPSTORE
			add(jmp,p+1)
			return 0
		end,
		function()				--JUMPBACK
			if #jmp==0 then error("nothing to jump back to!; byte #" .. p) end
			p=self.jmp[#jmp]
			jmp[#jmp]=nil
			return 0
		end,
		function(self)				--JUMPTO
			p=_gv(p+1,9)
			return 2
		end,
		function()					--DEBUGPRINT
			printh("table #" c[p+1] .. " key["  .. self:getkey(p+1,p+2) .. "]=" .. tostr(_gv(p+1,1)))
			return 2
		end
	}

	while p<=#c do
		local t=self.var[c[p+1]]
		if _c[c[p]] then
			local ad=_c[c[p]](self)
			p+=ad+1
		else error("unknown opbyte #" .. c[p] .. "; byte #" .. p) end
	end
end