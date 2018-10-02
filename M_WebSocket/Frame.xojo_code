#tag Class
Private Class Frame
	#tag Method, Flags = &h0
		Shared Function Decode(dataMB as MemoryBlock, byref offset as UInt64) As M_WebSocket.Frame()
		  Dim frames() As M_WebSocket.Frame
		  offset = 0
		  While offset < dataMB.Size
		    
		    dataMB.LittleEndian = false
		    Dim dataPtr As Ptr = dataMB
		    
		    Dim isFinal As Boolean = (dataPtr.Byte(offset) And &b10000000) <> 0
		    Dim opCode As Integer = dataPtr.Byte(offset) And &b01111111
		    dim type as Message.Types = Message.Types( opCode )
		    
		    if Message.ValidTypes.IndexOf( type ) = -1 then
		      raise new WebSocketException( "Packet type is invalid" )
		    end if
		    
		    Dim lenCode As Byte = dataPtr.Byte(offset + 1)
		    dim masked as boolean = ( lenCode and &b10000000 ) <> 0
		    lenCode = lenCode and &b01111111
		    
		    dim dataLen as UInt64
		    Dim firstDataByte As Integer = offset + 2
		    
		    select case lenCode
		    case 127
		      dataLen = dataMB.UInt64Value(offset + 2)
		      firstDataByte = firstDataByte + 8
		      
		    Case 126
		      dataLen = dataMB.UInt16Value(offset + 2)
		      firstDataByte = firstDataByte + 2
		      
		    case else
		      dataLen = lenCode
		      
		    end select
		    
		    Dim lastDataByte As Integer = firstDataByte + dataLen
		    
		    if masked and dataLen > 0 then
		      dim maskMB as MemoryBlock = dataMB.StringValue( firstDataByte, 4 )
		      dim maskPtr as Ptr = maskMB
		      
		      firstDataByte = firstDataByte + 4
		      
		      dim maskIndex as integer
		      for i as integer = firstDataByte to lastDataByte
		        dataPtr.Byte( i ) = dataPtr.Byte( i ) xor maskPtr.Byte( maskIndex )
		        
		        maskIndex = maskIndex + 1
		        if maskIndex = 4 then
		          maskIndex = 0
		        end if
		      next
		    End If
		    
		    Dim data As String
		    Try
		      data = If(dataLen > 0, dataMB.StringValue(firstDataByte, lastDataByte - firstDataByte), "")
		    Catch ex As OutOfBoundsException
		      Exit While
		    End Try
		    
		    if isFinal and type = Message.Types.Text then
		      //
		      // Make sure it's UTF-8
		      //
		      if not Encodings.UTF8.IsValidData( data ) then
		        raise new WebSocketException( "The data was not valid UTF-8" )
		      end if
		      data = data.DefineEncoding( Encodings.UTF8 )
		    end if
		    
		    Dim r As New M_WebSocket.Frame
		    
		    r.IsFinal = isFinal
		    r.Type = type
		    r.IsMasked = masked
		    r.Content = data
		    
		    frames.Append r
		    
		    offset = lastDataByte
		  Wend
		  
		  Return frames
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Operator_Convert() As String
		  return ToString
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Content As String
	#tag EndProperty

	#tag Property, Flags = &h0
		IsFinal As Boolean = True
	#tag EndProperty

	#tag Property, Flags = &h0
		IsMasked As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  dim finCodeNibble as byte = if( IsFinal, &b10000000, 0 )
			  dim opCodeNibble as byte = integer( Type )
			  dim firstByte as byte = finCodeNibble + opCodeNibble
			  
			  const uZero as UInt64 = 0
			  
			  dim useLength as UInt64 = content.LenB
			  dim lenCode as byte
			  
			  dim lenMB as MemoryBlock
			  select case useLength
			  case is > &hFFFF
			    lenMB = new MemoryBlock( 8 )
			    lenMB.LittleEndian = false
			    lenMB.UInt64Value( 0 ) = useLength
			    lenCode = 127
			    
			  case is > 125
			    lenMB = new MemoryBlock( 2 )
			    lenMB.LittleEndian = false
			    lenMB.UInt16Value( 0 ) = useLength
			    lenCode = 126
			    
			  case else
			    lenCode = useLength
			    
			  end select
			  
			  dim dataMB as MemoryBlock = Content
			  dim maskMB as MemoryBlock
			  
			  if IsMasked and Content <> "" then
			    lenCode = lenCode or &b10000000
			    
			    maskMB = Crypto.GenerateRandomBytes( 4 )
			    dim maskIndex as integer
			    dim lastByte as integer = dataMB.Size - 1
			    dim dataPtr as Ptr = dataMB
			    dim maskPtr as Ptr = maskMB
			    
			    for i as integer = 0 to lastByte
			      dataPtr.Byte( i ) = dataPtr.Byte( i ) xor maskPtr.Byte( maskIndex )
			      maskIndex = maskIndex + 1
			      if maskIndex = 4 then
			        maskIndex = 0
			      end if
			    next
			  end if
			  
			  //
			  // Assemble it all
			  //
			  
			  dim mask as string = if( maskMB isa Object, maskMB.StringValue( 0, maskMB.Size ), "" )
			  dim sendData as string = if( dataMB.Size > 0, dataMB.StringValue( 0, dataMB.Size ),  "" )
			  dim r as string = _
			  ChrB( firstByte ) + _
			  ChrB( lenCode ) + _
			  if( lenMB isa object, lenMB.StringValue( 0, lenMB.Size ), "" ) + _
			    mask + _
			    sendData
			    
			    return r
			    
			    
			End Get
		#tag EndGetter
		ToString As String
	#tag EndComputedProperty

	#tag Property, Flags = &h0
		Type As Message.Types = Message.Types.Unknown
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Content"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsFinal"
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsMasked"
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ToString"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
