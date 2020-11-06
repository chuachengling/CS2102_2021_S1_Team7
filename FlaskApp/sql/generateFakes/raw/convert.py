with open('sampleMessages.txt', 'r') as sampleIn, open('sampleMessagesFormatted.txt', 'w') as sampleOut:
	for line in sampleIn:
		sampleOut.write(line.replace('’', '\'')\
			.replace('‘', '\'')\
			.replace('”', '"')\
			.replace('“', '"')\
			.replace('—', '-'))