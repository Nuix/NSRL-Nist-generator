require 'java'
require 'net/http'
require 'uri'
require 'fileutils'
require "set"
java_import 'java.nio.file.Files'
java_import javax.swing.JOptionPane
import javax.swing.JCheckBox
import javax.swing.JDialog
import javax.swing.JFrame
import javax.swing.JLabel
import javax.swing.JPanel
import javax.swing.JProgressBar
import javax.swing.UIManager
import javax.swing.WindowConstants
import java.awt.Font
$cache = java.io.File.new(__FILE__).getParent() + "/temp/";

def secondsToElapsed(inputseconds)
	if(inputseconds < 0)
		inputseconds=inputseconds*-1
	end
	mm, ss = inputseconds.divmod(60)
	hh, mm = mm.divmod(60)
	dd, hh = hh.divmod(24)
	if(dd > 0)
		return "%d days, %d hours" % [dd, hh]
	else
		if(hh> 0)
			return "%d hours, %d minutes" % [hh, mm]
		else
			if(mm > 0)
				return "%d minutes and %d seconds" % [mm, ss]
			else
				return "%d seconds" % [ss]
			end
		end
	end
end

class DownloadReadExportDialog < JDialog
	def initialize(title)
		super nil, true
		UIManager.setLookAndFeel("com.sun.java.swing.plaf.windows.WindowsLookAndFeel")
		self.setTitle(title)
		self.setSize(400, 355)
		self.setAlwaysOnTop(true)
		self.setResizable(false)
		self.setLayout(nil)
		self.setLocationRelativeTo(nil)
		self.setDefaultCloseOperation(JFrame::DISPOSE_ON_CLOSE)

		@jlabelDownload = JLabel.new() 
		@jlabelDownload.setSize(370, 15)
		@jlabelDownload.setLocation(10,10)
		@jlabelDownload.setFont(@jlabelDownload.getFont().deriveFont(Font::BOLD))
		@jlabelDownload.setText("Downloading:")

		@jlabelDownloadMessage = JLabel.new() 
		@jlabelDownloadMessage.setSize(370, 15)
		@jlabelDownloadMessage.setLocation(10,35)

		@jlabelDownloadProgress = JProgressBar.new() 
		@jlabelDownloadProgress.setSize(370, 20)
		@jlabelDownloadProgress.setLocation(10,60)
		@jlabelDownloadProgress.setStringPainted(true)

		@jlabelRead = JLabel.new() 
		@jlabelRead.setSize(370, 15)
		@jlabelRead.setLocation(10,100)
		@jlabelRead.setFont(@jlabelDownload.getFont().deriveFont(Font::BOLD))
		@jlabelRead.setText("Reading:")

		@jlabelReadMessage = JLabel.new() 
		@jlabelReadMessage.setSize(370, 15)
		@jlabelReadMessage.setLocation(10,125)

		@jlabelReadProgress = JProgressBar.new() 
		@jlabelReadProgress.setSize(370, 20)
		@jlabelReadProgress.setLocation(10,150)
		@jlabelReadProgress.setStringPainted(true)
		
		
		
		@jlabelExport = JLabel.new() 
		@jlabelExport.setSize(370, 15)
		@jlabelExport.setLocation(10,190)
		@jlabelExport.setFont(@jlabelDownload.getFont().deriveFont(Font::BOLD))
		@jlabelExport.setText("Exporting:")

		@jlabelExportMessage = JLabel.new() 
		@jlabelExportMessage.setSize(370, 15)
		@jlabelExportMessage.setLocation(10,215)

		@jlabelExportProgress = JProgressBar.new() 
		@jlabelExportProgress.setSize(370, 20)
		@jlabelExportProgress.setLocation(10,240)
		@jlabelExportProgress.setStringPainted(true)
		
		

		self.add(@jlabelDownload)
		self.add(@jlabelDownloadMessage)
		self.add(@jlabelDownloadProgress)
		self.add(@jlabelRead)
		self.add(@jlabelReadMessage)
		self.add(@jlabelReadProgress)
		self.add(@jlabelExport)
		self.add(@jlabelExportMessage)
		self.add(@jlabelExportProgress)

		Thread.new{
				yield self
			sleep(0.2)
			self.dispose()
		}
		self.setVisible(true)

	end

	def setDownloadMax(max)
		@jlabelDownloadProgress.setMaximum(max)
	end


	def setDownloadCurrent(current)
		@jlabelDownloadProgress.setValue(current)
	end

	def setDownloadMessage(message)
		@jlabelDownloadMessage.setText(message)
	end

	def setReadMax(max)
		@jlabelReadProgress.setMaximum(max)
	end


	def setReadCurrent(current)
		@jlabelReadProgress.setValue(current)
	end

	def setReadMessage(message)
		@jlabelReadMessage.setText(message)
	end
	
	def setExportMax(max)
		@jlabelExportProgress.setMaximum(max)
	end
	

	def setExportCurrent(current)
		@jlabelExportProgress.setValue(current)
	end

	def setExportMessage(message)
		@jlabelExportMessage.setText(message)
	end

	def close()
		self.setVisible(false)
		self.dispose()
	end
end


def show_message(message,title="Message")
	jf=JFrame.new();
	jf.setAlwaysOnTop(true); #ensure it's on top!
	JOptionPane.showMessageDialog(jf,message,title,JOptionPane::PLAIN_MESSAGE)
end

def getCheckedInput(settings,title="Checked Input",description="")
	if(settings.class!=Hash) 
		#puts settings
		raise "settings are expected in hash values, e.g. {\"setting1\"=>true}"
	end
	settings.reject! {|k,v|(!(v.class==TrueClass || v.class==FalseClass))}
	if(settings.nil?)
		raise "settings are expected in hash=>true/false values, e.g. {\"setting1\"=>true}"
	end
	if(settings.length ==0)
		raise "settings are expected in hash=>true/false values, e.g. {\"setting1\"=>true}"
	end
	panel = JPanel.new(java.awt.GridLayout.new(0,1))
	if(description!="")
		panel.add(JLabel.new(description))
	end
	controls=Array.new()
	settings.each do | setting,value|
		cb = JCheckBox.new setting, value
		cb.setFocusable(false)
		panel.add(cb)
		controls.push cb
	end
	JOptionPane.showMessageDialog(JFrame.new, panel,title,JOptionPane::PLAIN_MESSAGE );

	responses=Hash.new()
	controls.each do | control|
		responses[control.getText()]=control.isSelected()
	end
	return responses
end






def downloadFile(url,sha=nil) #TODO: check sha
	begin
		uri = URI(url)
		url_base = url.split('/')[2]
		url_path = '/'+url.split('/')[3..-1].join('/')
		baseName=File.basename(uri.path)
		cachePath=$cache + baseName
		if(File.file?(cachePath))
			if(sha.nil?)
				if (block_given?)
					yield 100,100
				end
				return cachePath
			end
			sif=$utilities.createSourceItemFactory()
			cacheObj=sif.openFile(cachePath)
			sha1Cached=cacheObj.getDigests().getSha1()
			sif.close()
			if(sha1Cached==sha)
				if (block_given?)
					yield 100,100
				end
				return cachePath
			end
		end
		#puts "Sha does not match, downloading..."
		progress = 0
		Net::HTTP.start(uri.host, uri.port,  :use_ssl => uri.scheme == 'https') do |http|
			response = http.request_head(URI.escape(url_path))
			totalsize=response['content-length'].to_i
			if(totalsize==0)
				totalsize=-1
			end
			File.open($cache + "/" + baseName, 'w') do |f|
				http.get(URI.escape(url_path)) do |str|
					f.write str
					progress += str.length 
					if (block_given?)
						yield progress,totalsize
					end
				end
			end
		end
		return $cache + "/" + baseName
	rescue Exception => ex
		puts ex.message
		puts ex.backtrace
	end
end

catalogue=downloadFile("https://s3.amazonaws.com/rds.nsrl.nist.gov/RDS/current/README.txt")
details={}
lines=File.readlines(catalogue).map(&:strip)
release=lines[0]

blocks=lines.each_index.select{|i| lines[i] == '----------'}.map{|i|i-1}
blocks.each do | block |
	header=lines[block]
	payload=lines[block+2]
	payloadSize=payload.split(' ')[1]
	payload=payload.split(' ')[0]
	shaUrl=lines[block+3].split(' ')[0]
	details[header]={
		"url"=>payload,
		"size"=>payloadSize,
		"shaUrl"=>shaUrl
	}
end


selection={}

details.each {|key,value|selection[key + "\t" + value["size"]]=false}
selection=getCheckedInput(selection,"Which items do you want to download?",release)

selectedKeys=selection.keys.select{|key|selection[key]==true}

selectedKeys=selectedKeys.map{|keyWithSize|keyWithSize.split("\t")[0]}

if(selectedKeys.length == 0)
	show_message("No digests selected","Finished")
	return
end


statMutex = Mutex.new
stats={"Downloading"=>{},"Reading"=>{}}
selectedKeys.each do | selectedKey |
	stats["Downloading"][selectedKey]=0
	stats["Reading"][selectedKey]=0
end


queue=Set.new([])
queueMutex = Mutex.new

digestDir=java.io.File.new(java.lang.System.getProperty('nuix.userDataBase') + '/Digest Lists')

if(!digestDir.exists())
	if(!digestDir.mkdir())
		digestDir=java.io.File.new(__FILE__) #defaulting back to the script directory if the script does not have access to the user database... 
		begin
			while(digestDir.getName().downcase() != "nuix")
				#puts digestDir.getName()
				digestDir=java.io.File.new(digestDir.getParent())
			end
			digestDir=java.io.File.new(digestDir.to_s + "/Digest Lists")
			if(!digestDir.exists())
				if(!digestDir.mkdir())
					#puts "oh dear... we can't make even the digest list here..."
					digestDir=java.io.File.new(__FILE__) #defaulting back to the script directory if the script does not have access to the user database... 
				end
			end
		rescue Exception => ex
			puts ex
			puts ex.backtrace
			puts digestDir
			digestDir=java.io.File.new(__FILE__) #defaulting back to the script directory if the script does not have access to the user database... 
		end		
	end
end
$digestListFile=java.io.File.new(digestDir.to_s + '/' + release + '.hash').to_s #including all the names had to be removed because it was breaching windows file path length (funny but true!)

puts "When finished the digest list will be available here:\n" + $digestListFile
File.open($digestListFile,"wb") do |file| #this is the wrapper even before the GUI because if the file can't be created this is all for nothing... so it may as well be made first.
	#Write headers
	file.write("F2DL")
	file.write([1].pack('N'))
	file.write([3].pack('n'))  # length of "MD5"
	file.write("MD5")
	
	DownloadReadExportDialog.new("Creating " + release + '.hash') do | dialog |
		dialog.setDownloadMax(selectedKeys.length * 100.00)
		dialog.setReadMax(selectedKeys.length * 100.00)
		activities=[]
		$errors=false
		selectedKeys.each_with_index do | selectedKey,index |
			activities[index]=Thread.new{
				begin
					details[selectedKey]["sha"]=File.readlines(downloadFile(details[selectedKey]["shaUrl"])).map(&:strip).join("").split('=')[1].strip()
					#puts details[selectedKey]["url"]
					rawCompressedItem=downloadFile(details[selectedKey]["url"],details[selectedKey]["sha"]) do | progress,fileTotal |
						#puts "Downloading #{fileTotal},#{total}\t#{selectedKey}"
						statMutex.synchronize do 
							stats["Downloading"][selectedKey]=100.00 * progress / fileTotal
							current=stats["Downloading"].values.inject(0, :+)
							dialog.setDownloadCurrent(current)
							dialog.setDownloadMessage("#{stats["Downloading"].values.select{|val|val != 100}.length} remaining items")
						end
					end
					statMutex.synchronize do 
						stats["Downloading"][selectedKey]=100.00
						current=stats["Downloading"].values.inject(0, :+)
						dialog.setDownloadCurrent(current)
						dialog.setDownloadMessage("#{stats["Downloading"].values.select{|val|val != 100}.length} remaining items")
					end
					sif=utilities.createSourceItemFactory()
					rawContainer=sif.openFile(rawCompressedItem)
					#puts rawContainer.getName()
					if(rawContainer.getChildren().to_a.length() == 1)
						rawContainer=rawContainer.getChildren().first() #usually it's a simple folder and underneath that is the file we are looking for
					else
						rawContainer.getChildren().each do | child | #sometimes they are nested in zips
							if(child.getName()=="NSRLFILE.ZIP")
								rawContainer=child
							end
						end
					end
					rawContainer.getChildren().each do | child |
						if(child.getName()!="NSRLFile.txt")
							puts "Skipping:" + child.getName()
							next
						end
						unitPercent=100.00 / child.getFileSize()
						progress=0
						inputStream=child.getBinary().getBinaryData().getInputStream()
						reader = java.io.BufferedReader.new(java.io.InputStreamReader.new(inputStream));
						while(reader.ready())
							String line = reader.readLine()
							progress=progress+line.length
							statMutex.synchronize do 
								stats["Reading"][selectedKey]=progress * unitPercent
								current=stats["Reading"].values.inject(0, :+)
								dialog.setReadCurrent(current)
								dialog.setReadMessage("#{stats["Reading"].values.select{|val|val != 100}.length} remaining items")
							end
							line_sections=line.split(',')
							md5_string=line_sections[1]
							if(md5_string=='"MD5"')
								next
							end
							md5_only=md5_string.gsub(/[^a-fA-F0-9]/,'')
							
							if(md5_only.length == 32)
								queueMutex.synchronize do # ruby sortedSet is not guarenteed to be threadsafe... so a mutex is here to stop any funny business from happening.
									md5_bytes=Array(md5_only).pack('H*') #packing it to save on memory space but also because the final format requires it anyway... win/win scenario for memory!
									queue.add(md5_bytes)
								end
							else
								puts "BAD MD5:#{md5_only}" #should never get here... allow it but we are't using it for the digest list
							end
						end
						#ensure it's finished in the UI
						statMutex.synchronize do 
							stats["Reading"][selectedKey]=100
							current=stats["Reading"].values.inject(0, :+)
							dialog.setReadCurrent(current)
							dialog.setReadMessage("#{stats["Reading"].values.select{|val|val != 100}.length} remaining items")
						end
						break
					end
					sif.close()
				rescue Exception => ex
					puts ex
					puts ex.backtrace
					$errors=true
				end
			}
		end
		puts("waiting on threads to complete")
		activities.each(&:join)
		if($errors)
			show_message("Error occured, most likely because of a memory issue - see log","Oh dear, aborting")
			return
		end
		puts "sorting..."
		dialog.setExportMax(queue.length)
		queue=queue.to_a.sort!
		puts "writing to file"
		
		#Write hashes
		queue.each_with_index do | md5_bytes,index|
			file.write(md5_bytes)
			dialog.setExportCurrent(index)
			dialog.setExportMessage("#{queue.length - index} remaining items")
		end
	end
end
show_message("#{queue.length} unique md5's included in exported file","Finished")
exit
