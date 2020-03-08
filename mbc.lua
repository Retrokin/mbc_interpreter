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
	function(self,c,p)			--FUNCTION
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
	end
}


mbc_runner=cwi:new{
	--code={}
}

function mbc_runner:init()
	self.code,self.var,self.vark={},{},{}
	for i=0,255 do
		self.vars[i]={}
	end
end

function mbc_runner:access(t,id)
	
end

function mbc_runner:getkey(t,id)
	if t==1 then					--block variables
		if #self.vars[254]>0 then return self.vars[0][254][#self.vars[0][254]]+id+1 end
	elseif id>9 and id<100 then
		for k,v in pairs(self.vars[t]) do
			if sub(k,#k-1,#k)==id then return k end
		end
	end
	return id
end

function mbc_runner:getvar(t,id)
	return self.vars[t][self:getkey(t,id)]
end

function mbc_runner:compile(c,p,l)
	self.code[c]={}
	for i=0,l-1 do
		add(self.code[c],peek(p+i))
	end
end

function mbc_runner:run(c)
	self.jumps={}
	c=self.code[c]
	local p,jmp,a2,a3,p4=1,{}

	local function _gv(p,t)
		if not t then
			t=p
			p+=1
		end
		if mbc_genvar[t] then mbc_genvar[t](c,p,self)
		else error("No variable type #" .. t .. "Line #" .. p) end
	end
	local _c={							--all code commands
		function(self) 					--VAR
			local v,ad,ns=_gv(p+4)
			if a3==0 then t[ns]=v						--SET
			elseif a3==1 then t[ns]+=v					--ADD
			elseif a3==2 then t[ns]-=v					--SUB
			elseif a3==3 then t[ns]*=v					--MUL
			elseif a3==4 then t[ns]/=v					--DIV
			elseif a3==5 then t[ns]=t[ns] .. v			--CONCAT
			elseif a3==6 then t[ns]=t[ns]==v				--IFEQUAL
			elseif a3==7 then t[ns]=t[ns]<v				--IFLESS
			elseif a3==8 then t[ns]=t[ns]<=v			--IFLESSEQUAL
			elseif a3==9 then t=v end 					--SETTABLE
			return ad
		end,
		function(self)					--LUANAME
			local s,ad=_gv(p+3,6)
			t[a2]=s .. "_" .. c[a2]
			return ad
		end,
		function(self)					--FUNC
			local ad=_gv(p+1,1)
			
			return 3
		end,
		function()				--JUMPSTORE
			add(jmp,p+1)
			return 0
		end,
		function()				--JUMPBACK
			if #jmp==0 then error("Nothing to jump back to! Line #" .. p) end
			p=self.jmp[#jmp]
			jmp[#jmp]=nil
			return 0
		end,
		function(self)				--JUMPTO
			p=_gv(p+1,5)
			return 2
		end
	}
	
	while p<=#c do
		a2,a3,p4=c[p+2],c[p+3],p+4
		local t=self.vars[c[p+1]]
		if _c[c[p]] then
			local ad=_c[c[p]](self)
			p+=ad+1
		else error("Unknown command #" .. c[p]) end
	end
end