import csv, random, time, tkinter as tk
from datetime import datetime, timezone
from pathlib import Path
from tkinter import messagebox

TARGET_SEC, FIXATION_SEC, ITI_SEC = 5, 6, 1
BLOCKS, TRIALS_PER_BLOCK = 4, 20
IMAGES = ["Apple", "Flower", "Bicycle", "House"]

def now(): return datetime.now(timezone.utc).isoformat(timespec="milliseconds")
def fixation(c):
    c.delete("all"); c.create_text(125, 95, text="+", font=("Arial", 56, "bold"), fill="#222")
def picture(c, name):
    c.delete("all"); x, y = 125, 95
    if name == "Apple":
        c.create_oval(65, 55, 130, 145, fill="#e53935", outline="#922", width=3); c.create_oval(120, 55, 185, 145, fill="#ef5350", outline="#922", width=3); c.create_line(125, 58, 137, 25, width=7, fill="#654321"); c.create_oval(135, 22, 175, 45, fill="#43a047", outline="#27632a")
    elif name == "Flower":
        c.create_line(x, 110, x, 175, width=8, fill="#2e7d32")
        for a,b in [(75,45),(125,20),(175,45),(75,95),(175,95)]: c.create_oval(a-25,b-25,a+25,b+25,fill="#ec407a",outline="#ad1457",width=2)
        c.create_oval(108,73,142,107,fill="#ffca28",outline="#f57f17",width=2)
    elif name == "Bicycle":
        c.create_oval(30,110,100,180,outline="#1565c0",width=5); c.create_oval(150,110,220,180,outline="#1565c0",width=5); c.create_line(65,145,110,75,185,145,65,145,fill="#263238",width=5); c.create_line(110,75,125,145,fill="#263238",width=5); c.create_line(95,65,120,65,fill="#263238",width=5); c.create_line(170,115,190,75,fill="#263238",width=5)
    else:
        c.create_polygon(35,90,125,20,215,90,fill="#ef5350",outline="#8e2424",width=3); c.create_rectangle(55,90,195,175,fill="#ffcc80",outline="#8d6e63",width=3); c.create_rectangle(108,130,142,175,fill="#795548"); c.create_rectangle(70,105,98,132,fill="#90caf9"); c.create_rectangle(152,105,180,132,fill="#90caf9")

class Sender:
    def __init__(self):
        self.root=tk.Tk(); self.root.title("ESP Experiment — Sender"); self.root.geometry("700x560"); self.root.configure(bg="#f4f4f4")
        self.index=0; self.rows=[]; self.build_setup()
    def clear(self):
        for w in self.root.winfo_children(): w.destroy()
    def build_setup(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=35,pady=30); f.pack(expand=True)
        tk.Label(f,text="ESP Experiment — Sender",font=("Arial",23,"bold"),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="Pair ID",bg="#f4f4f4").pack(anchor="w"); self.pair=tk.Entry(f,font=("Arial",15),width=30); self.pair.pack(pady=5)
        tk.Label(f,text="Participant label",bg="#f4f4f4").pack(anchor="w"); self.label=tk.Entry(f,font=("Arial",15),width=30); self.label.insert(0,"Sender"); self.label.pack(pady=5)
        tk.Button(f,text="Continue",font=("Arial",14),command=self.prepare).pack(pady=20)
    def prepare(self):
        self.pair_id=self.pair.get().strip(); self.label_text=self.label.get().strip() or "Sender"
        if not self.pair_id: messagebox.showerror("Missing Pair ID","Enter the shared Pair ID."); return
        self.sequence=[]
        rng=random.SystemRandom()
        for block in range(1,BLOCKS+1):
            targets=IMAGES*5; rng.shuffle(targets); self.sequence.extend((block,t) for t in targets)
        Path("esp_data").mkdir(exist_ok=True)
        stamp=datetime.now().strftime("%Y%m%d_%H%M%S"); self.path=Path("esp_data")/f"{self.pair_id}_sender_{stamp}.csv"
        self.file=open(self.path,"w",newline="",encoding="utf-8"); self.writer=csv.DictWriter(self.file,fieldnames=["pair_id","participant_label","block","trial","target","target_onset_utc","target_offset_utc","fixation_onset_utc"]); self.writer.writeheader(); self.file.flush()
        self.instructions()
    def instructions(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=35,pady=30); f.pack(expand=True)
        tk.Label(f,text="Instructions",font=("Arial",22,"bold"),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="A target image appears for 5 seconds, followed by a fixation cross for 6 seconds. Do not communicate with the receiver. There are 4 blocks of 20 trials.",wraplength=580,font=("Arial",14),bg="#f4f4f4").pack(pady=15)
        tk.Label(f,text="Coordinate a spoken countdown with the receiver. Both click Start at the same agreed moment.",wraplength=580,font=("Arial",12),bg="#f4f4f4").pack(pady=15)
        tk.Button(f,text="Start",font=("Arial",16,"bold"),command=self.start,padx=25,pady=8).pack(pady=20)
    def start(self):
        self.clear(); self.status=tk.Label(self.root,font=("Arial",16,"bold"),bg="#f4f4f4"); self.status.pack(pady=20)
        self.canvas=tk.Canvas(self.root,width=250,height=190,bg="white"); self.canvas.pack(pady=20)
        self.timer=tk.Label(self.root,bg="#f4f4f4",font=("Arial",12)); self.timer.pack()
        self.count=3; self.countdown()
    def countdown(self):
        if self.count: self.status.config(text=f"Starting in {self.count}..."); self.count-=1; self.root.after(1000,self.countdown)
        else: self.run_trial()
    def run_trial(self):
        if self.index>=len(self.sequence): self.finish(); return
        block,target=self.sequence[self.index]; trial=self.index%TRIALS_PER_BLOCK+1
        self.status.config(text=f"Block {block}/{BLOCKS} — Trial {trial}/{TRIALS_PER_BLOCK}"); picture(self.canvas,target); onset=now(); self.timer.config(text="Focus on the target image")
        self.root.after(TARGET_SEC*1000,lambda:self.show_fixation(target,onset))
    def show_fixation(self,target,onset):
        offset=now(); fixation(self.canvas); fixation_onset=now(); self.timer.config(text="Fixation — keep looking at the cross")
        block,target2=self.sequence[self.index]
        self.writer.writerow(dict(pair_id=self.pair_id,participant_label=self.label_text,block=block,trial=self.index+1,target=target,target_onset_utc=onset,target_offset_utc=offset,fixation_onset_utc=fixation_onset)); self.file.flush()
        self.root.after(FIXATION_SEC*1000,self.end_trial)
    def end_trial(self):
        self.index+=1
        if self.index%TRIALS_PER_BLOCK==0 and self.index<len(self.sequence): self.block_break()
        else: self.timer.config(text="Next trial shortly"); fixation(self.canvas); self.root.after(ITI_SEC*1000,self.run_trial)
    def block_break(self):
        self.clear(); f=tk.Frame(self.root,bg="#f4f4f4",padx=30,pady=30); f.pack(expand=True)
        tk.Label(f,text=f"Block {self.index//TRIALS_PER_BLOCK} complete",font=("Arial",22,"bold"),bg="#f4f4f4").pack(pady=20)
        tk.Label(f,text="Take a break. Coordinate with the receiver, then both click Start Next Block together.",wraplength=560,font=("Arial",14),bg="#f4f4f4").pack(pady=15)
        tk.Button(f,text="Start Next Block",font=("Arial",15),command=self.start,padx=20,pady=8).pack(pady=20)
    def finish(self):
        self.file.close(); self.clear(); tk.Label(self.root,text=f"Experiment complete\nSender data saved to:\n{self.path.resolve()}",font=("Arial",15),bg="#f4f4f4").pack(expand=True)
    def run(self): self.root.mainloop()

if __name__=="__main__": Sender().run()
