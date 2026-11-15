-- DayNight v1.3 (клиент): плавно меняет свет и небо по времени суток. Расчёт у каждого игрока свой — сеть не нагружается.
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local DN=require(RS:WaitForChild('DayNight'))
local t0=os.clock()
while workspace:GetAttribute('DN_T0')==nil and os.clock()-t0<8 do task.wait(.1) end -- ждём, пока сервер задаст точку отсчёта
local acc=0
RunService.RenderStepped:Connect(function(dt)
 acc+=dt;if acc<.1 then return end
 acc=0
 DN.apply(DN.hour())
end)
