VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "cDelaunay"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

'*********************************************************************************
'Main reference:
'1. "Primitives for the Manipulation of General Subdivisions and the
'   Computation of Voronoi Diagrams", Guibas and Stolfi
'2. Quad-Edge Data Structure and Library, Paul Heckbert
'   http://www.cs.cmu.edu/afs/andrew/scs/cs/15-463/2001/pub/src/a2/quadedge.html
'*********************************************************************************

Private pn As Long, pn_dimension As Long, pn_edge As Long
Private px() As Double          'vertex positions (1:N,1:2)
Private px_value() As Double      'value (height, density..etc.) at each vertex (1:N)
Private px_sort_idx() As Long   'order of vertices (1:N)
Private pEdge_L As cQuadEdge    'CCW convex hull edge out of leftmost vertex
Private pEdge_R As cQuadEdge    'CW convex hull edge out of rightmost vertex
Private Const pz_tol = 0.000000000000001 '1E-15

Sub Reset()
Dim i As Long
    pn = 0
    pn_dimension = 0
    pn_edge = 0
    Erase px, px_sort_idx, px_value
    Set pEdge_L = Nothing
    Set pEdge_R = Nothing
End Sub

Public Property Get Size() As Long
    Size = pn
End Property

Public Property Get n_edge() As Long
    n_edge = pn_edge
End Property

'========================================================================================
'Output edge_list(1:n_edge,1:2), edge_length(1:n_edge), node_pos(1:n,1:2), node_wgt(1:n)
'which can be used to create new graph class cGraph_Dir or cGraph_Undir
'========================================================================================
Sub Output_Graph_node_pos(node_pos() As Double)
    node_pos = px
End Sub

Sub Output_Graph_node_wgt(node_wgt() As Double)
    node_wgt = px_value
End Sub

Sub Output_Graph_EdgeList(edge_list() As Long, edge_length() As Double)
Dim i As Long, j As Long, k As Long, m As Long, n As Long, n_edge As Long
Dim EdgeVisited As Collection
Dim x_edge As cQuadEdge
    Call Traverse_All_Edges(EdgeVisited)
    k = 0
    n_edge = EdgeVisited.count
    ReDim edge_list(1 To n_edge, 1 To 2)
    ReDim edge_length(1 To n_edge)
    Do While EdgeVisited.count > 0
        k = k + 1
        Set x_edge = EdgeVisited(1)
        EdgeVisited.Remove (1)
        i = x_edge.Org: j = x_edge.Dest
        edge_list(k, 1) = i
        edge_list(k, 2) = j
        edge_length(k) = Sqr((px(i, 1) - px(j, 1)) ^ 2 + (px(i, 2) - px(j, 2)) ^ 2)
    Loop
    Set x_edge = Nothing
    Set EdgeVisited = Nothing
End Sub
      
'=========================================================================
'Plot the grid-lines of delaunay triangulation as scatter chart in Excel
'node_list(1:M) stores the corresponding integer pointer to input dataset
'=========================================================================
Sub Plot(vArr As Variant, Optional node_list As Variant)
Dim i As Long, j As Long, k As Long, m As Long
Dim EdgeVisited As Collection
    Call Traverse_All_Edges(EdgeVisited)
    Call EdgeList_2_ExcelChart(vArr, EdgeVisited, node_list)
    Set EdgeVisited = Nothing
End Sub

'=========================================================================
'Plot the grid-lines of a DFS-path as scatter chart in Excel
'node_list(1:M) stores the corresponding integer pointer to input dataset
'=========================================================================
Function Plot_DFS(vArr As Variant, Optional node_list As Variant) As Variant
Dim i As Long, j As Long, k As Long, m As Long
Dim EdgeVisited As Collection
    Call Traverse_All_Nodes(EdgeVisited)
    Call EdgeList_2_ExcelChart(vArr, EdgeVisited, node_list)
    Set EdgeVisited = Nothing
End Function

'=========================================================================
'Plot the grid-lines of Voronoi diagram as scatter chart in Excel
'=========================================================================
Sub Plot_Voronoi(vArr As Variant)
Dim i As Long, j As Long, k As Long, m As Long, n_edge As Long
Dim u As Long, v As Long, w As Long, w_L As Long, w_R As Long
Dim uArr As Variant
Dim A As cQuadEdge, B As cQuadEdge, C As cQuadEdge, A_prev As cQuadEdge
Dim EdgeVisited As Collection
Dim tmp_x As Double, tmp_y As Double, tmp_xx As Double, tmp_yy As Double
Dim isL_Valid As Boolean, isR_Valid As Boolean, isShow As Boolean
    Call Traverse_All_Edges_Voronoi(EdgeVisited, True)
    ReDim uArr(1 To 2, 0 To 0)
    Do While EdgeVisited.Count > 0
        
        If EdgeVisited.Count Mod 1000 = 0 Then
            DoEvents
        End If
        Set A = EdgeVisited(1)
        EdgeVisited.Remove (1)
  
        u = A.Org: v = A.Dest
        
        Set B = A.Lnext
        w_L = B.Dest
        If B.Lnext.Dest = u Then
            isL_Valid = True
        Else
            isL_Valid = False
        End If
        
        Set B = A.Rprev
        w_R = B.Dest
        If B.Rprev.Dest = u Then
            isR_Valid = True
        Else
            isR_Valid = False
        End If
        
        isShow = True
        If isL_Valid And isR_Valid Then
            Call Calc_Center(tmp_x, tmp_y, u, v, w_L)
            Call Calc_Center(tmp_xx, tmp_yy, u, v, w_R)
        ElseIf isL_Valid And isR_Valid = False Then
            Call Calc_Center(tmp_x, tmp_y, u, v, w_L)
            If isInsideHull(tmp_x, tmp_y) Then
                tmp_xx = (px(u, 1) + px(v, 1)) / 2
                tmp_yy = (px(u, 2) + px(v, 2)) / 2
            Else
                isShow = False
            End If
        ElseIf isL_Valid = False And isR_Valid Then
            Call Calc_Center(tmp_xx, tmp_yy, u, v, w_R)
            If isInsideHull(tmp_xx, tmp_yy) Then
                tmp_x = (px(u, 1) + px(v, 1)) / 2
                tmp_y = (px(u, 2) + px(v, 2)) / 2
            Else
                isShow = False
            End If
        End If
        
        If isShow Then
            k = UBound(uArr, 2)
            If k = 0 Then
                ReDim uArr(1 To 2, 1 To 2)
                uArr(1, 1) = tmp_x
                uArr(2, 1) = tmp_y
                uArr(1, 2) = tmp_xx
                uArr(2, 2) = tmp_yy
            Else
                If (A Is A_prev.Oprev And A.Lnext Is A_prev.Dnext) _
                        Or (A Is A_prev.Dnext And A.Lprev Is A_prev.Oprev) Then
                    ReDim Preserve uArr(1 To 2, 1 To k + 1)
                    uArr(1, k + 1) = tmp_xx
                    uArr(2, k + 1) = tmp_yy
                Else
                    ReDim Preserve uArr(1 To 2, 1 To k + 3)
                    uArr(1, k + 2) = tmp_x
                    uArr(2, k + 2) = tmp_y
                    uArr(1, k + 3) = tmp_xx
                    uArr(2, k + 3) = tmp_yy
                End If
            End If
            Set A_prev = A
        End If
    Loop
    
    m = UBound(uArr, 2)
    ReDim vArr(1 To m, 1 To 2)
    For j = 1 To 2
        For i = 1 To m
            vArr(i, j) = uArr(j, i)
        Next i
    Next j
End Sub


'Convert an ordered list of edges into chartable x-y positions
Private Sub EdgeList_2_ExcelChart(vArr As Variant, EdgeVisited As Collection, node_list As Variant)
Dim i As Long, j As Long, k As Long, m As Long, n As Long
Dim u As Long, v As Long, w As Long, u_prev As Long, v_prev As Long
Dim A As cQuadEdge, uArr As Variant
    
    m = EdgeVisited.Count
    k = 0: u_prev = -1: v_prev = -1
    For Each A In EdgeVisited
        k = k + 1
        If k Mod 500 = 0 Then
            DoEvents
            Application.StatusBar = "Plotting Edges: " & k & "/" & m
        End If
        u = A.Org
        v = A.Dest
        If u = v_prev Then
            m = UBound(vArr, 2)
            ReDim Preserve vArr(1 To 2, 1 To m + 1)
            ReDim Preserve node_list(1 To m + 1)
            vArr(1, m + 1) = px(v, 1)
            vArr(2, m + 1) = px(v, 2)
            node_list(m + 1) = v
        Else
            If k = 1 Then
                m = -1
                ReDim vArr(1 To 2, 1 To 2)
                ReDim node_list(1 To 2)
            Else
                m = UBound(vArr, 2)
                ReDim Preserve vArr(1 To 2, 1 To m + 3)
                ReDim Preserve node_list(1 To m + 3)
            End If
            vArr(1, m + 2) = px(u, 1)
            vArr(2, m + 2) = px(u, 2)
            vArr(1, m + 3) = px(v, 1)
            vArr(2, m + 3) = px(v, 2)
            node_list(m + 2) = u
            node_list(m + 3) = v
        End If
        u_prev = u: v_prev = v
    Next A
    
    n = UBound(vArr, 2)
    uArr = vArr
    ReDim vArr(1 To n, 1 To 2)
    For j = 1 To 2
        For i = 1 To n
            vArr(i, j) = uArr(j, i)
        Next i
    Next j
    Application.StatusBar = False
End Sub

'Traverse all edges in the Delaunay tessellation along the hull, starting from the leftmost edge and grow inwards
Private Sub Traverse_All_Edges(EdgeVisited As Collection, Optional reset_visit As Boolean = True)
Dim i As Long, j As Long, k As Long, m As Long
Dim u As Long, v As Long, w As Long
Dim A As cQuadEdge, B As cQuadEdge
Dim EdgeStack As Collection
Dim uArr As Variant, node_list As Variant
    Set EdgeVisited = New Collection    'edges in visited order
    Set EdgeStack = New Collection      'Stack of edges to be visited next
    Set A = pEdge_L                     'First edge pointer
    Set B = A
    Do
        Set B = B.Onext
        EdgeStack.Add B
        If B Is A Then Exit Do
    Loop
    k = 0: j = 0
    Do While EdgeStack.Count > 0
    
        k = k + 1
        If k Mod 2000 = 0 Then
            DoEvents
            Application.StatusBar = "Traversing Edges: " & EdgeStack.Count
        End If
        
        m = EdgeStack.Count
        Set A = EdgeStack(m)
        EdgeStack.Remove (m)

        If Not A.isVisited Then
            A.isVisited = True
            EdgeVisited.Add A
            Set B = A.Lnext
            Do
                If Not B.isVisited Then EdgeStack.Add B
                Set B = B.Oprev
                If B Is A.Sym Then Exit Do
            Loop
        End If
    Loop
    Set EdgeStack = Nothing
    If reset_visit = True Then
        For Each A In EdgeVisited
            A.isVisited = False
        Next A
    End If
    Application.StatusBar = False
End Sub

'Traverse all nodes in the Delaunay tessellation starting from the leftmost node spiral inwards
Private Sub Traverse_All_Nodes(EdgeVisited As Collection, Optional reset_visit As Boolean = True)
Dim i As Long, j As Long, k As Long, m As Long
Dim u As Long, v As Long, w As Long
Dim A As cQuadEdge, B As cQuadEdge
Dim EdgeStack As Collection
Dim isVisited() As Long

    ReDim isVisited(1 To pn)
    Set EdgeVisited = New Collection    'edges in visited order
    Set EdgeStack = New Collection      'Stack of edges to be visited next
    Set A = pEdge_L                     'First edge pointer
    isVisited(A.Org) = 1
    Set B = A
    Do
        Set B = B.Onext
        EdgeStack.Add B
        If B Is A Then Exit Do
    Loop
    k = 0: j = 0
    Do While EdgeStack.Count > 0
        k = k + 1
        If k Mod 2000 = 0 Then
            DoEvents
            Application.StatusBar = "Traversing Node: " & EdgeStack.Count & "/" & pn
        End If
        
        m = EdgeStack.Count
        Set A = EdgeStack(m)
        u = A.Org: v = A.Dest
        EdgeStack.Remove (m)
        
        If isVisited(v) = 0 Then
            isVisited(v) = 1
            EdgeVisited.Add A
            Set B = A.Lnext
            Do
                EdgeStack.Add B
                Set B = B.Oprev
                If B Is A.Sym Then Exit Do
            Loop
        End If
    Loop
    Set EdgeStack = Nothing
    If reset_visit = True Then
        For Each A In EdgeVisited
            A.isVisited = False
        Next A
    End If
    Application.StatusBar = False
End Sub


'Traverse all edges in the Delaunay tessellation in order natural for Voronoi
Private Sub Traverse_All_Edges_Voronoi(EdgeVisited As Collection, Optional reset_visit As Boolean = True)
Dim i As Long, j As Long, k As Long, m As Long
Dim u As Long, v As Long, w As Long
Dim A As cQuadEdge, B As cQuadEdge
Dim EdgeStack As Collection
    Call Traverse_All_Edges(EdgeVisited, True)
    Set A = EdgeVisited(EdgeVisited.Count)  'Start from innermost edge
    'Set A = pEdge_L.Oprev               'First edge pointer
    Set EdgeVisited = New Collection    'edges in visited order
    Set EdgeStack = New Collection      'Stack of edges to be visited next
    EdgeStack.Add A
    k = 0
    Do While EdgeStack.Count > 0
    
        k = k + 1
        If k Mod 2000 = 0 Then
            DoEvents
            Application.StatusBar = "Traversing Edges (Voronoi): " & EdgeStack.Count
        End If
        
        Set A = EdgeStack(1)
        EdgeStack.Remove (1)

        If Not A.isVisited Then
            A.isVisited = True
            EdgeVisited.Add A

            Set B = A
            Do
                Set B = B.Oprev
                EdgeStack.Add B
                If B Is A Then Exit Do
            Loop

            Set B = A.Lnext
            Do
                If Not B.isVisited Then EdgeStack.Add B
                Set B = B.Oprev
                If B Is A.Sym Then Exit Do
            Loop

        End If
    Loop
    Set EdgeStack = Nothing
    If reset_visit = True Then
        For Each A In EdgeVisited
            A.isVisited = False
        Next A
    End If
    Application.StatusBar = False
End Sub

'========================================================================
'Create a Delaunay tessellation of a set of 2-D points
'Duplicates need to be resolved beforehand
'========================================================================
'Input:
'x(1:N,1:2), x-y positions of the N vertices
'x_value(1:N), field values of the N vertices
Sub Init(x As Variant, Optional x_value As Variant = Null)
Dim i As Long, j As Long, k As Long, m As Long
Dim A As cQuadEdge, B As cQuadEdge, C As cQuadEdge
Dim tmp_vec() As Double, iArr() As Long, xArr() As Double, tmp_x As Double
Dim x_ptr() As Long, isDuplicate() As Long, n_duplicate As Long
    If UBound(x, 2) <> 2 Then
        Debug.Print "cDelaunay: only supports 2-dimensional at the moment."
        Exit Sub
    End If
    pn = UBound(x, 1)
    pn_dimension = UBound(x, 2)
    ReDim px(1 To pn, 1 To pn_dimension)
    For j = 1 To pn_dimension
        For i = 1 To pn
            px(i, j) = x(i, j)
        Next i
    Next j
    
    ReDim tmp_vec(1 To pn)
    For i = 1 To pn
        tmp_vec(i) = px(i, 1)
    Next i
    Call Sort_Quick_A(tmp_vec, 1, pn, px_sort_idx, 1)

    'If ties exist in first dimension then sort by the second dimension
    i = 1
    n_duplicate = 0: ReDim isDuplicate(1 To pn)
    Do While i < pn
        tmp_x = tmp_vec(i)
        If Almost_Equal(tmp_vec(i), tmp_vec(i + 1)) Then
            m = i + 1
            For j = i + 2 To pn
                If Not Almost_Equal(tmp_vec(j), tmp_vec(i)) Then
                    m = j - 1
                    Exit For
                Else
                    m = j
                End If
            Next j
            ReDim iArr(1 To m - i + 1)
            ReDim xArr(1 To m - i + 1)
            For k = 1 To m - i + 1
                iArr(k) = px_sort_idx(i + k - 1)
                xArr(k) = px(px_sort_idx(i + k - 1), 2)
            Next k
            Call Sort_Quick_A(xArr, 1, m - i + 1, iArr, 0)
            For k = 1 To m - i + 1
                px_sort_idx(i + k - 1) = iArr(k)
                If k > 1 Then
                    If Almost_Equal(xArr(k), xArr(k - 1)) Then
                        n_duplicate = n_duplicate + 1
                        isDuplicate(iArr(k)) = 1
                    End If
                End If
            Next k
            i = m + 1
        Else
            i = i + 1
        End If
    Loop

    'Remove pointers of duplicate data
    If n_duplicate > 0 Then
        Debug.Print "cDelaunay: Caution: " & n_duplicate & " duplicates found."
    End If
    iArr = px_sort_idx
    pn = pn - n_duplicate: k = 0
    ReDim px_sort_idx(1 To pn)
    For i = 1 To UBound(iArr)
        j = iArr(i)
        If isDuplicate(j) = 0 Then
            k = k + 1
            px_sort_idx(k) = j
        End If
    Next i
    Erase iArr, isDuplicate
    
    If Not IsNull(x_value) Then
        ReDim px_value(1 To pn)
        For i = 1 To pn
            px_value(i) = x_value(i)
        Next i
    End If
    
    'Perform triangulation
    Call Delaunay_Step(px_sort_idx, pEdge_L, pEdge_R)
    Application.StatusBar = False
End Sub

'Recursive divide and conquer algorithm to create Delaunay Triangulation
Private Sub Delaunay_Step(x_ptr() As Long, Edge_L As cQuadEdge, Edge_R As cQuadEdge)
Dim i As Long, j As Long, k As Long, n As Long, n_L As Long, n_R As Long
Dim A As cQuadEdge, B As cQuadEdge, C As cQuadEdge
Dim ldo As cQuadEdge, ldi As cQuadEdge
Dim rdo As cQuadEdge, rdi As cQuadEdge
Dim x_ptr_L() As Long, x_ptr_R() As Long
Dim vArr As Variant, tmp_x As Double, tmp_y As Double

    n = UBound(x_ptr)
    
    If n = 2 Then
    
        Set A = New cQuadEdge: Call A.Init
        A.Org = x_ptr(1)
        A.Dest = x_ptr(2)
        Set Edge_L = A
        Set Edge_R = A.Sym

    ElseIf n = 3 Then

        Set A = New cQuadEdge: Call A.Init
        Set B = New cQuadEdge: Call B.Init
        Call Splice(A.Sym, B)
        A.Org = x_ptr(1)
        A.Dest = x_ptr(2)
        B.Org = x_ptr(2)
        B.Dest = x_ptr(3)
        If isCCW(x_ptr(1), x_ptr(2), x_ptr(3)) Then
            Set C = ConnectEdge(B, A)
            Set Edge_L = A
            Set Edge_R = B.Sym
        ElseIf isCCW(x_ptr(1), x_ptr(3), x_ptr(2)) Then
            Set C = ConnectEdge(B, A)
            Set Edge_L = C.Sym
            Set Edge_R = C
        Else
            Set Edge_L = A
            Set Edge_R = B.Sym
        End If

    ElseIf n >= 4 Then

        n_L = n \ 2
        n_R = n - n_L
        ReDim x_ptr_L(1 To n_L)
        ReDim x_ptr_R(1 To n_R)
        For i = 1 To n_L
            x_ptr_L(i) = x_ptr(i)
        Next i
        For i = 1 To n_R
            x_ptr_R(i) = x_ptr(n_L + i)
        Next i

        Call Delaunay_Step(x_ptr_L, ldo, ldi)
        Call Delaunay_Step(x_ptr_R, rdi, rdo)
        
        If n > (pn / 4) Then
            DoEvents
            Application.StatusBar = "Delaunay Triangulation: " & n & ": " & n_L & "-" & n_R
        End If
        
        Call Delaunay_Merge(ldo, ldi, rdi, rdo, Edge_L, Edge_R)
        
    End If
End Sub

Private Sub Delaunay_Merge(ldo As cQuadEdge, ldi As cQuadEdge, rdi As cQuadEdge, rdo As cQuadEdge, _
                Edge_L As cQuadEdge, Edge_R As cQuadEdge)
Dim lcand As cQuadEdge, rcand As cQuadEdge, basel As cQuadEdge, t As cQuadEdge
Dim isValid_L As Boolean, isValid_R As Boolean
        
    Do
        If isLeftOf(rdi.Org, ldi) Then
            Set ldi = ldi.Lnext
        ElseIf isRightOf(ldi.Org, rdi) Then
            Set rdi = rdi.Rprev
        Else
            Exit Do
        End If
    Loop

    Set basel = ConnectEdge(rdi.Sym, ldi)
    If ldi.Org = ldo.Org Then Set ldo = basel.Sym
    If rdi.Org = rdo.Org Then Set rdo = basel
    
    Do

        Set lcand = basel.Sym.Onext
        If isValid(lcand, basel) Then
            Do While inCircle(basel.Dest, basel.Org, lcand.Dest, lcand.Onext.Dest)
                Set t = lcand.Onext
                Call DeleteEdge(lcand)
                Set lcand = t
            Loop
        End If
        
        Set rcand = basel.Oprev
        If isValid(rcand, basel) Then
            Do While inCircle(basel.Dest, basel.Org, rcand.Dest, rcand.Oprev.Dest)
                Set t = rcand.Oprev
                Call DeleteEdge(rcand)
                Set rcand = t
            Loop
        End If
        
        isValid_L = isValid(lcand, basel)
        isValid_R = isValid(rcand, basel)
        
        If Not isValid_L And Not isValid_R Then Exit Do
        
        If Not isValid_L Or _
                (isValid_R And inCircle(lcand.Dest, lcand.Org, rcand.Org, rcand.Dest)) Then
            Set basel = ConnectEdge(rcand, basel.Sym)
        Else
            Set basel = ConnectEdge(basel.Sym, lcand.Sym)
        End If

    Loop

    Set Edge_L = ldo
    Set Edge_R = rdo
End Sub



'==================================================================================
'Basic Quad-Edge operations and tests
'These follow the conventions in Guibas and Stolfi, see illustrations therein
'==================================================================================
Private Sub Splice(A As cQuadEdge, B As cQuadEdge)
Dim t1 As cQuadEdge, t2 As cQuadEdge, t3 As cQuadEdge, t4 As cQuadEdge
Dim alpha As cQuadEdge, beta As cQuadEdge

    Set alpha = A.Onext.Rot
    Set beta = B.Onext.Rot
    
    Set t1 = B.Onext
    Set t2 = A.Onext
    Set t3 = beta.Onext
    Set t4 = alpha.Onext
    
    Set A.Nxt = t1
    Set B.Nxt = t2
    Set alpha.Nxt = t3
    Set beta.Nxt = t4
    
End Sub

Private Function ConnectEdge(A As cQuadEdge, B As cQuadEdge) As cQuadEdge
Dim C As cQuadEdge
    Set C = New cQuadEdge
    Call C.Init
    C.Org = A.Dest
    C.Dest = B.Org
    Call Splice(C, A.Lnext)
    Call Splice(C.Sym, B)
    Set ConnectEdge = C
End Function

Private Sub DeleteEdge(A As cQuadEdge)
    Call Splice(A, A.Oprev)
    Call Splice(A.Sym, A.Sym.Oprev)
End Sub

Private Sub SwapEdge(C As cQuadEdge)
Dim A As cQuadEdge, B As cQuadEdge
    Set A = C.Oprev
    Set B = C.Sym.Oprev
    Call Splice(C, A)
    Call Splice(C.Sym, B)
    Call Splice(C, A.Lnext)
    Call Splice(C.Sym, B.Lnext)
    C.Org = A.Dest
    C.Dest = B.Dest
End Sub

Private Function inCircle(u As Long, v As Long, w As Long, p As Long) As Boolean
Dim tmp_x As Double, tmp_y As Double, tmp_z As Double
Dim vArr As Variant
    If px(u, 1) = px(v, 1) And px(u, 1) = px(w, 1) Then
        inCircle = True
        Exit Function
    ElseIf px(u, 2) = px(v, 2) And px(u, 2) = px(w, 2) Then
        inCircle = True
        Exit Function
    End If
    ReDim vArr(1 To 4, 1 To 4)
    vArr(1, 1) = px(u, 1): vArr(1, 2) = px(u, 2): vArr(1, 3) = px(u, 1) ^ 2 + px(u, 2) ^ 2: vArr(1, 4) = 1
    vArr(2, 1) = px(v, 1): vArr(2, 2) = px(v, 2): vArr(2, 3) = px(v, 1) ^ 2 + px(v, 2) ^ 2: vArr(2, 4) = 1
    vArr(3, 1) = px(w, 1): vArr(3, 2) = px(w, 2): vArr(3, 3) = px(w, 1) ^ 2 + px(w, 2) ^ 2: vArr(3, 4) = 1
    vArr(4, 1) = px(p, 1): vArr(4, 2) = px(p, 2): vArr(4, 3) = px(p, 1) ^ 2 + px(p, 2) ^ 2: vArr(4, 4) = 1
    tmp_x = Application.WorksheetFunction.MDeterm(vArr)
    If tmp_x > 0 Then
        inCircle = True
    Else
        inCircle = False
    End If
End Function

Private Function isCCW(u As Long, v As Long, w As Long) As Boolean
Dim tmp_x As Double
    If px(u, 1) = px(v, 1) And px(u, 1) = px(w, 1) Then
        isCCW = False
    ElseIf px(u, 2) = px(v, 2) And px(u, 2) = px(w, 2) Then
        isCCW = False
    Else
        tmp_x = px(v, 1) * px(w, 2) - px(v, 2) * px(w, 1) _
                - (px(u, 1) * px(w, 2) - px(u, 2) * px(w, 1)) _
                + (px(u, 1) * px(v, 2) - px(u, 2) * px(v, 1))
        If tmp_x > 0 Then
            isCCW = True
        Else
            isCCW = False
        End If
    End If
End Function

Private Function isCollinear(u As Long, v As Long, w As Long) As Boolean
Dim tmp_x As Double
    If px(u, 1) = px(v, 1) And px(u, 1) = px(w, 1) Then
        isCollinear = True
    ElseIf px(u, 2) = px(v, 2) And px(u, 2) = px(w, 2) Then
        isCollinear = True
    Else
        tmp_x = px(v, 1) * px(w, 2) - px(v, 2) * px(w, 1)
        tmp_x = tmp_x - (px(u, 1) * px(w, 2) - px(u, 2) * px(w, 1))
        tmp_x = tmp_x + (px(u, 1) * px(v, 2) - px(u, 2) * px(v, 1))
        If Abs(tmp_x) <= pz_tol Then
            isCollinear = True
        Else
            isCollinear = False
        End If
    End If
End Function

Private Function isRightOf(u As Long, A As cQuadEdge) As Boolean
    isRightOf = isCCW(u, A.Dest, A.Org)
End Function

Private Function isLeftOf(u As Long, A As cQuadEdge) As Boolean
    isLeftOf = isCCW(u, A.Org, A.Dest)
End Function

Private Function isValid(A As cQuadEdge, basel As cQuadEdge)
    isValid = isRightOf(A.Dest, basel)
End Function

'Returns the three vertex u-v-w that encapsulate point (x,y) in a delaunay triangle,
'also returns tgt_edge whose left face is the triangle
Private Sub Locate_xy(x As Double, y As Double, tgt_edge As cQuadEdge, _
            u As Long, v As Long, w As Long, Optional init_edge As Variant = Null)
Dim iterate As Long
Dim A As cQuadEdge
Dim tmp_x As Double, tmp_y As Double
    'Check that point lies inside the convex-hull, returns nothing otherwise
    If Not isInsideHull(x, y) Then
        Set tgt_edge = Nothing
        u = -1: v = -1: w = -1
        Exit Sub
    End If

    If VBA.IsNull(init_edge) Then
        Set A = pEdge_L
    Else
        Set A = init_edge
    End If

    iterate = 0
    Do
        iterate = iterate + 1
        If iterate Mod 100 = 0 Then
            DoEvents
            Application.StatusBar = "cDelaunay: Locate_xy: Stuck:" & iterate & ", (" & x & ", " & y & ")"
        End If
        
        If (Almost_Equal(x, px(A.Org, 1)) And Almost_Equal(y, px(A.Org, 2))) _
                Or (Almost_Equal(x, px(A.Dest, 1)) And Almost_Equal(y, px(A.Dest, 2))) Then
            Set tgt_edge = A
            u = A.Org: v = A.Dest: w = -1       '(x,y) lies on A, use only 2 points to intrapolate
            Exit Sub
        ElseIf isCollinear_xy(x, y, A, tmp_x) Then
            If tmp_x >= 0 And tmp_x <= 1 Then   '(x,y) lies on A, use only 2 points to intrapolate
                Set tgt_edge = A
                u = A.Org: v = A.Dest: w = -1
                Exit Sub
            ElseIf tmp_x > 1 Then
                If isLeftOf_xy(x, y, A.Lnext) Then
                    Set A = A.Lnext
                ElseIf isLeftOf_xy(x, y, A.Rprev) Then
                    Set A = A.Rprev
                Else
                    Set A = A.Lnext
                End If
            ElseIf tmp_x < 0 Then
                Set A = A.Sym.Lnext
            End If
        ElseIf isRightOf_xy(x, y, A) Then
            Set A = A.Sym
        ElseIf Not isRightOf_xy(x, y, A.Onext) Then
            Set A = A.Onext
        ElseIf Not isRightOf_xy(x, y, A.Dprev) Then
            Set A = A.Dprev
        Else
            Set tgt_edge = A
            Exit Do
        End If
    Loop
    With tgt_edge
        u = .Org: v = .Dest: w = .Lnext.Dest
    End With
    
    Application.StatusBar = False
End Sub

    Private Function isRightOf_xy(x As Double, y As Double, A As cQuadEdge) As Boolean
        isRightOf_xy = isCCW_xy(x, y, A.Dest, A.Org)
    End Function
    
    Private Function isLeftOf_xy(x As Double, y As Double, A As cQuadEdge) As Boolean
        isLeftOf_xy = isCCW_xy(x, y, A.Org, A.Dest)
    End Function
    
    Private Function isCCW_xy(x As Double, y As Double, v As Long, w As Long) As Boolean
    Dim tmp_x As Double
        If x = px(v, 1) And x = px(w, 1) Then
            isCCW_xy = False
        ElseIf y = px(v, 2) And y = px(w, 2) Then
            isCCW_xy = False
        Else
            tmp_x = px(v, 1) * px(w, 2) - px(v, 2) * px(w, 1) _
                    - (x * px(w, 2) - y * px(w, 1)) _
                    + (x * px(v, 2) - y * px(v, 1))
            If tmp_x > 0 Then
                isCCW_xy = True
            Else
                isCCW_xy = False
            End If
        End If
    End Function

    Private Function isCollinear_xy(x As Double, y As Double, A As cQuadEdge, x_loc As Double) As Boolean
    Dim u As Long, v As Long
    Dim tmp_x As Double
        isCollinear_xy = False
        u = A.Org: v = A.Dest
        If x = px(u, 1) And x = px(v, 1) Then
            isCollinear_xy = True
            x_loc = (y - px(u, 2)) / (px(v, 2) - px(u, 2))
        ElseIf y = px(u, 2) And y = px(v, 2) Then
            isCollinear_xy = True
            x_loc = (x - px(u, 1)) / (px(v, 1) - px(u, 1))
        Else
            tmp_x = px(u, 1) * px(v, 2) - px(u, 2) * px(v, 1) _
                    - (x * px(v, 2) - y * px(v, 1)) _
                    + (x * px(u, 2) - y * px(u, 1))
            If tmp_x = 0 Then
                isCollinear_xy = True
                x_loc = (x - px(u, 1)) * (px(v, 1) - px(u, 1)) + (y - px(u, 2)) * (px(v, 2) - px(u, 2))
                x_loc = x_loc / ((px(v, 1) - px(u, 1)) ^ 2 + (px(v, 2) - px(u, 2)) ^ 2)
            End If
        End If
    End Function
    
    Private Function isInsideHull(x As Double, y As Double) As Boolean
    Dim A As cQuadEdge
        isInsideHull = True
        Set A = pEdge_L
        Do
            If isRightOf_xy(x, y, A) Then
                isInsideHull = False
                Exit Function
            End If
            Set A = A.Rprev
            If A Is pEdge_L Then Exit Do
        Loop
    End Function
    
    Private Sub Calc_Center(x As Double, y As Double, u As Long, v As Long, w As Long)
    Dim tmp_det As Double, d_uv As Double, d_uw As Double
        tmp_det = px(v, 1) * px(w, 2) - px(v, 2) * px(w, 1)
        tmp_det = tmp_det - (px(u, 1) * px(w, 2) - px(u, 2) * px(w, 1))
        tmp_det = tmp_det + (px(u, 1) * px(v, 2) - px(u, 2) * px(v, 1))
        
        d_uv = px(u, 1) ^ 2 - px(v, 1) ^ 2 + px(u, 2) ^ 2 - px(v, 2) ^ 2
        d_uw = px(u, 1) ^ 2 - px(w, 1) ^ 2 + px(u, 2) ^ 2 - px(w, 2) ^ 2
        
        x = (d_uv * (px(u, 2) - px(w, 2)) - d_uw * (px(u, 2) - px(v, 2))) / (2 * tmp_det)
        y = -(d_uv * (px(u, 1) - px(w, 1)) - d_uw * (px(u, 1) - px(v, 1))) / (2 * tmp_det)
    End Sub




'=========================================
'Basic math operations
'=========================================
Private Function Almost_Equal(x As Variant, y As Variant) As Boolean
    If Abs(x - y) <= pz_tol Then
        Almost_Equal = True
    Else
        Almost_Equal = False
    End If
End Function

Private Sub Sort_Quick_A(vArray As Variant, inLow As Long, inHi As Long, sort_index() As Long, Optional first_run As Long = 1)
Dim pivot   As Double
Dim tmpSwap As Variant
Dim tmpLow As Long, tmpHi As Long, i As Long
    If first_run = 1 Then
        ReDim sort_index(LBound(vArray) To UBound(vArray))
        For i = LBound(vArray) To UBound(vArray)
            sort_index(i) = i
        Next i
    End If
    tmpLow = inLow
    tmpHi = inHi
    pivot = vArray((inLow + inHi) \ 2)
    While (tmpLow <= tmpHi)
        While (vArray(tmpLow) < pivot And tmpLow < inHi)
            tmpLow = tmpLow + 1
        Wend
        
        While (pivot < vArray(tmpHi) And tmpHi > inLow)
            tmpHi = tmpHi - 1
        Wend
        
        If (tmpLow <= tmpHi) Then
            tmpSwap = vArray(tmpLow)
            vArray(tmpLow) = vArray(tmpHi)
            vArray(tmpHi) = tmpSwap
            
            i = sort_index(tmpLow)
            sort_index(tmpLow) = sort_index(tmpHi)
            sort_index(tmpHi) = i
            
            tmpLow = tmpLow + 1
            tmpHi = tmpHi - 1
        End If
    Wend
    If (inLow < tmpHi) Then Sort_Quick_A vArray, inLow, tmpHi, sort_index, 0
    If (tmpLow < inHi) Then Sort_Quick_A vArray, tmpLow, inHi, sort_index, 0
End Sub


'===============================================
'Delaunay Tessellation Field Estimators, Schaap
'===============================================
Sub Density_Est(x_density() As Double)
Dim i As Long, j As Long, k As Long
Dim tmp_x As Double
Dim A As cQuadEdge
Dim EdgeVisited As Collection
    Call Traverse_All_Nodes(EdgeVisited)
    ReDim x_density(1 To pn)
    Set A = EdgeVisited(1)
    tmp_x = Area_around_Vertex(A, "ORG", k)
    x_density(A.Org) = 3# / tmp_x
    Do While EdgeVisited.Count > 0
        Set A = EdgeVisited(1)
        EdgeVisited.Remove (1)
        tmp_x = Area_around_Vertex(A, "DEST", k)
        x_density(A.Dest) = 3# / tmp_x
    Loop
    Set EdgeVisited = Nothing
End Sub

    Private Function Area_around_Vertex(A As cQuadEdge, strType As String, n_neighbor As Long) As Double
    Dim i As Long, j As Long, k As Long
    Dim u As Long, v As Long, w As Long
    Dim tmp_x As Double
    Dim A_copy As cQuadEdge, B As cQuadEdge, C As cQuadEdge
        tmp_x = 0: n_neighbor = 0
        Set A_copy = A
        If strType = "ORG" Then
            u = A_copy.Org
        ElseIf strType = "DEST" Then
            u = A_copy.Dest
            Set A_copy = A_copy.Sym
        End If
        Set C = A_copy
        Do
            n_neighbor = n_neighbor + 1
            If C.Lnext.Lnext.Dest = u Then
                v = C.Dest
                w = C.Lnext.Dest
                tmp_x = tmp_x + Calc_Area_Triangle(u, v, w)
            End If
            Set C = C.Onext
            If C Is A_copy Then Exit Do
        Loop
        Area_around_Vertex = tmp_x
    End Function

    Private Function Calc_Area_Triangle(u As Long, v As Long, w As Long) As Double
    Calc_Area_Triangle = 0.5 * Abs(px(u, 1) * px(v, 2) + px(v, 1) * px(w, 2) + px(w, 1) * px(u, 2) _
                - px(v, 1) * px(u, 2) - px(w, 1) * px(v, 2) - px(u, 1) * px(w, 2))
    End Function


'=======================================================================================================
'Generate 3-dimesional plot x(1:N,1:3), where the first two columns are positions and the third is height
'=======================================================================================================
'Input:  x(1:N,1:3), datapoints at x-y positions with value z
'Output: x_lines(1:M,1:3), lines to creat 3D chart on a Delaunay triangulation
Sub Plot_xyz(x As Variant, x_lines As Variant)
Dim i As Long, j As Long, k As Long, m As Long, n As Long
Dim vArr As Variant, uArr As Variant
Dim x_pos() As Double
Dim x_avg() As Double, x_sd() As Double
Dim tmp_x As Double, tmp_y As Double

    n = UBound(x, 1)
    ReDim x_avg(1 To 3)
    ReDim x_sd(1 To 3)
    For j = 1 To 3
        tmp_x = 0: tmp_y = 0
        For i = 1 To n
            tmp_x = tmp_x + x(i, j)
            tmp_y = tmp_y + x(i, j) ^ 2
        Next i
        x_avg(j) = tmp_x / n
        x_sd(j) = Sqr(tmp_y / n - (tmp_x / n) ^ 2)
    Next j
    
    ReDim x_pos(1 To n, 1 To 2)
    For j = 1 To 2
        For i = 1 To n
            x_pos(i, j) = (x(i, j) - x_avg(j)) / x_sd(j)
        Next i
    Next j
    With Me
        Call .Init(x_pos)
        Call .Plot(x_lines, uArr)
        Call .Reset
    End With
    
    n = UBound(x_lines, 1)
    ReDim Preserve x_lines(1 To n, 1 To 3)
    For i = 1 To n
        If Not VBA.IsEmpty(uArr(i)) Then
            x_lines(i, 3) = (x(uArr(i), 3) - x_avg(3)) / x_sd(3)
        End If
    Next i

End Sub

'=========================================================================
'Using the currently saved positions and values adn their triangulations,
'use linear intrapolation to estimate values on a regular grid
'=========================================================================
'Input: n_x/y , min/max_x/y,   resolution and range of grid points to intrpolate on
'Output: x_value(1:n_y,1:n_x) , intrapolated values on grid
Sub Intrapolate_Grid(x_value As Variant, n_x As Long, n_y As Long, _
            min_x As Variant, max_x As Variant, min_y As Variant, max_y As Variant)
Dim i As Long, j As Long, k As Long, m As Long, n As Long
Dim u As Long, v As Long, w As Long
Dim tmp_x As Double, tmp_y As Double, tmp_z As Double
Dim d_x As Double, d_y As Double
Dim A As cQuadEdge, B As cQuadEdge
    ReDim x_value(1 To n_y, 1 To n_x)
    Set B = pEdge_L
    d_x = (max_x - min_x) / (n_x - 1)
    d_y = (max_y - min_y) / (n_y - 1)
    For i = 1 To n_y
        tmp_y = max_y - (i - 1) * d_y
        For j = 1 To n_x
            tmp_x = min_x + (j - 1) * d_x
            Call Locate_xy(tmp_x, tmp_y, A, u, v, w, B)
            If Not A Is Nothing Then
                tmp_z = Intrapolate_xy(tmp_x, tmp_y, u, v, w)
                x_value(i, j) = tmp_z
                Set B = A
            Else
                'points outside the convex hull are assumed to be zero
                Set B = pEdge_L
            End If
        Next j
    Next i
    Set A = Nothing
    Set B = Nothing
End Sub

Private Function Intrapolate_xy(x As Double, y As Double, u As Long, v As Long, w As Long) As Double
Dim tmp_x As Double, grad_x As Double, grad_y As Double
    If w < 0 Then
        tmp_x = (x - px(u, 1)) ^ 2 + (y - px(u, 2)) ^ 2
        tmp_x = Sqr(tmp_x / ((px(v, 1) - px(u, 1)) ^ 2 + (px(v, 2) - px(u, 2)) ^ 2))
        Intrapolate_xy = px_value(u) + (px_value(v) - px_value(u)) * tmp_x
    Else
        Call Intrapolate_grad(grad_x, grad_y, u, v, w)
        Intrapolate_xy = px_value(u) + grad_x * (x - px(u, 1)) + grad_y * (y - px(u, 2))
    End If
End Function

Private Sub Intrapolate_grad(grad_x As Double, grad_y As Double, u As Long, v As Long, w As Long)
grad_x = (px_value(v) - px_value(u)) * (px(w, 2) - px(u, 2)) - (px_value(w) - px_value(u)) * (px(v, 2) - px(u, 2))
grad_y = (px_value(v) - px_value(u)) * (px(w, 1) - px(u, 1)) - (px_value(w) - px_value(u)) * (px(v, 1) - px(u, 1))
If grad_x <> 0 Then
    grad_x = grad_x / ((px(v, 1) - px(u, 1)) * (px(w, 2) - px(u, 2)) - (px(w, 1) - px(u, 1)) * (px(v, 2) - px(u, 2)))
End If
If grad_y <> 0 Then
    grad_y = grad_y / ((px(v, 2) - px(u, 2)) * (px(w, 1) - px(u, 1)) - (px(w, 2) - px(u, 2)) * (px(v, 1) - px(u, 1)))
End If
End Sub